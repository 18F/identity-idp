# frozen_string_literal: true

module Idv
  # Parses mDL DeviceResponse (ISO 18013-5) from the Digital Credentials API.
  class MdlResponseParser
    MDL_DOCTYPE = 'org.iso.18013.5.1.mDL'
    MDL_NAMESPACE = 'org.iso.18013.5.1'

    # Maps mdoc element identifiers to our PII field names
    # Per ISO 18013-5 Section 7.2.1
    ELEMENT_MAPPING = {
      'family_name' => :last_name,
      'given_name' => :first_name,
      'birth_date' => :dob,
      'resident_street' => :address1,
      'resident_address' => :address1, # Alternative element name
      'resident_city' => :city,
      'resident_state' => :state,
      'resident_postal_code' => :zipcode,
      'resident_country' => :country,
      'document_number' => :state_id_number,
      'expiry_date' => :state_id_expiration,
      'issue_date' => :state_id_issued,
      'issuing_authority' => :issuing_authority,
      'issuing_jurisdiction' => :state_id_jurisdiction,
      'issuing_country' => :issuing_country_code,
      'sex' => :sex,
      'height' => :height,
      'weight' => :weight,
      'eye_colour' => :eye_color,
      'portrait' => :portrait, # Base64 encoded image
    }.freeze

    attr_reader :raw_response, :parsed_data, :errors, :session_data, :document_info

    def initialize(credential_data, session_data: nil)
      @raw_response = credential_data
      @session_data = session_data
      @parsed_data = {}
      @document_info = {}
      @errors = []
    end

    def parse
      return false if raw_response.blank?

      begin
        decoded = decode_response
        Rails.logger.info("[MdlResponseParser] Decoded response type: #{decoded.class}")

        if decoded.is_a?(Hash)
          extract_pii(decoded)
          extract_document_info(decoded)
        else
          @errors << 'Decoded response is not a valid structure'
          return false
        end

        if @parsed_data.empty?
          @errors << 'No PII data could be extracted from the response'
          return false
        end

        Rails.logger.info("[MdlResponseParser] Extracted #{@parsed_data.keys.count} PII fields")
        true
      rescue CBOR::MalformedFormatError => e
        @errors << "Invalid CBOR format: #{e.message}"
        Rails.logger.error("[MdlResponseParser] CBOR parse error: #{e.message}")
        false
      rescue StandardError => e
        @errors << "Failed to parse mDL response: #{e.message}"
        Rails.logger.error("[MdlResponseParser] Parse error: #{e.message}")
        Rails.logger.error(e.backtrace&.first(10)&.join("\n"))
        false
      end
    end

    def success?
      errors.empty? && parsed_data.present?
    end

    # Returns PII in the format expected by Pii::StateId
    def pii_from_mdl
      {
        first_name: normalize_string(parsed_data[:first_name]),
        last_name: normalize_string(parsed_data[:last_name]),
        middle_name: parsed_data[:middle_name],
        name_suffix: nil,
        dob: format_date(parsed_data[:dob]),
        address1: normalize_string(parsed_data[:address1]),
        address2: nil,
        city: normalize_string(parsed_data[:city]),
        state: normalize_string(parsed_data[:state]),
        zipcode: normalize_zipcode(parsed_data[:zipcode]),
        state_id_number: parsed_data[:state_id_number],
        state_id_jurisdiction: extract_jurisdiction,
        state_id_expiration: format_date(parsed_data[:state_id_expiration]),
        state_id_issued: format_date(parsed_data[:state_id_issued]),
        issuing_country_code: parsed_data[:issuing_country_code] || 'US',
        sex: normalize_sex(parsed_data[:sex]),
        height: parsed_data[:height],
        weight: parsed_data[:weight],
        eye_color: normalize_string(parsed_data[:eye_color])&.downcase,
        document_type_received: 'drivers_license',
      }
    end

    private

    def decode_response
      # The credential data could be:
      # 1. Base64-encoded CBOR
      # 2. Raw CBOR bytes
      # 3. JSON object containing the credential

      if raw_response.is_a?(Hash)
        # Already parsed JSON - look for the data field
        decode_from_hash(raw_response)
      elsif raw_response.is_a?(String)
        decode_from_string(raw_response)
      else
        raise 'Unknown response format'
      end
    end

    def decode_from_hash(hash)
      # The Digital Credentials API returns { protocol: "...", data: "..." }
      data = hash['data'] || hash[:data]
      if data.is_a?(String)
        decode_cbor(data)
      elsif data.is_a?(Hash)
        # Data might already be decoded
        data
      else
        raise 'No data field found in credential response'
      end
    end

    def decode_from_string(str)
      # Try Base64 decode first, then CBOR
      begin
        decoded_bytes = Base64.strict_decode64(str)
        CBOR.decode(decoded_bytes)
      rescue ArgumentError
        # Not Base64, try direct CBOR
        CBOR.decode(str.b)
      end
    end

    def decode_cbor(data)
      # Handle both Base64-encoded and raw CBOR
      bytes = if data.encoding == Encoding::BINARY || data.bytes.any? { |b| b > 127 }
                data.b
              else
                begin
                  Base64.strict_decode64(data)
                rescue ArgumentError
                  Base64.decode64(data) # More lenient
                end
              end

      CBOR.decode(bytes)
    end

    def extract_pii(device_response)
      # DeviceResponse structure (ISO 18013-5):
      # {
      #   "version" => "1.0",
      #   "documents" => [...],
      #   "status" => 0
      # }

      Rails.logger.info("[MdlResponseParser] Parsing device response: #{device_response.class}")
      Rails.logger.debug("[MdlResponseParser] Response keys: #{device_response.keys}") if device_response.is_a?(Hash)

      documents = device_response['documents'] || device_response[:documents] || []

      # Find the mDL document
      mdl_doc = documents.find do |doc|
        doc_type = doc['docType'] || doc[:docType]
        doc_type == MDL_DOCTYPE
      end

      if mdl_doc.nil? && documents.any?
        # Use first document if no mDL-specific one found
        mdl_doc = documents.first
        Rails.logger.warn('[MdlResponseParser] No mDL docType found, using first document')
      end

      return if mdl_doc.nil?

      extract_from_issuer_signed(mdl_doc)
    end

    def extract_from_issuer_signed(mdl_doc)
      issuer_signed = mdl_doc['issuerSigned'] || mdl_doc[:issuerSigned]
      return unless issuer_signed

      name_spaces = issuer_signed['nameSpaces'] || issuer_signed[:nameSpaces]
      return unless name_spaces

      # Get the standard mDL namespace
      mdl_namespace = name_spaces[MDL_NAMESPACE] || name_spaces.values.first
      return unless mdl_namespace

      # mdl_namespace is an array of IssuerSignedItem structures:
      # { "elementIdentifier" => "family_name", "elementValue" => "SMITH" }
      mdl_namespace.each do |item|
        extract_element(item)
      end
    end

    def extract_element(item)
      # Handle both tagged CBOR (IssuerSignedItem) and plain objects
      element_id = item['elementIdentifier'] || item[:elementIdentifier] || item[24]
      element_value = item['elementValue'] || item[:elementValue] || item[25]

      return unless element_id && ELEMENT_MAPPING.key?(element_id.to_s)

      field_name = ELEMENT_MAPPING[element_id.to_s]
      @parsed_data[field_name] = normalize_value(element_value)

      Rails.logger.debug("[MdlResponseParser] Extracted #{element_id}: #{element_value}")
    end

    def normalize_value(value)
      case value
      when CBOR::Tagged
        # Handle CBOR tagged values (e.g., dates tagged with 1004)
        normalize_tagged_value(value)
      when Hash
        # Some values might be structured (like full_date)
        value.values.first
      else
        value
      end
    end

    def normalize_tagged_value(tagged)
      case tagged.tag
      when 1004 # full-date (RFC 3339)
        tagged.value
      when 0 # date-time
        tagged.value
      else
        tagged.value
      end
    end

    def format_date(date_value)
      return nil if date_value.blank?

      # Handle various date formats
      case date_value
      when Date, Time, DateTime
        date_value.strftime('%Y-%m-%d')
      when String
        # Try to parse and reformat
        Date.parse(date_value).strftime('%Y-%m-%d')
      else
        date_value.to_s
      end
    rescue ArgumentError
      date_value.to_s
    end

    def extract_jurisdiction
      # Try multiple sources for jurisdiction
      parsed_data[:state_id_jurisdiction] ||
        parsed_data[:state] ||
        parsed_data[:issuing_authority]&.slice(0, 2)&.upcase
    end

    def extract_document_info(device_response)
      # Extract additional document metadata
      @document_info[:version] = device_response['version'] || device_response[:version]
      @document_info[:status] = device_response['status'] || device_response[:status]

      documents = device_response['documents'] || device_response[:documents] || []
      if documents.any?
        doc = documents.first
        @document_info[:doc_type] = doc['docType'] || doc[:docType]
      end
    end

    def normalize_string(value)
      return nil if value.blank?
      value.to_s.strip.upcase
    end

    def normalize_zipcode(value)
      return nil if value.blank?
      # Handle various zipcode formats, extract just the 5 or 9 digit code
      clean = value.to_s.gsub(/[^0-9]/, '')
      return clean[0, 5] if clean.length >= 5
      clean
    end

    def normalize_sex(value)
      return nil if value.blank?

      case value.to_s.downcase
      when 'm', 'male', '1'
        'male'
      when 'f', 'female', '2'
        'female'
      when 'x', 'non-binary', '0'
        'unspecified'
      else
        value.to_s.downcase
      end
    end
  end
end
