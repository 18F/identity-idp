# frozen_string_literal: true

module Mdoc
  class ResponseParser
    MDL_NAMESPACE = 'org.iso.18013.5.1'

    CLAIM_MAPPING = {
      'given_name' => :first_name,
      'family_name' => :last_name,
      'birth_date' => :dob,
      'resident_address' => :address1,
      'resident_city' => :city,
      'resident_state' => :state,
      'resident_postal_code' => :zipcode,
      'document_number' => :state_id_number,
      'expiry_date' => :state_id_expiration,
      'issue_date' => :state_id_issued,
      'issuing_authority' => :state_id_jurisdiction,
    }.freeze

    attr_reader :claims, :errors

    def initialize(raw_claims)
      @raw_claims = raw_claims
      @claims = {}
      @errors = []
    end

    def parse
      mdl_claims = @raw_claims&.dig(MDL_NAMESPACE) || @raw_claims
      if mdl_claims.blank?
        @errors << 'no mdl claims in response'
        return false
      end

      CLAIM_MAPPING.each do |source_key, pii_key|
        value = extract_value(mdl_claims, source_key)
        @claims[pii_key] = value if value.present?
      end

      if @claims.empty?
        @errors << 'could not extract pii'
        return false
      end

      true
    end

    def success?
      errors.empty? && claims.present?
    end

    def to_pii
      Pii::StateId.new(
        first_name: normalize(claims[:first_name]),
        last_name: normalize(claims[:last_name]),
        middle_name: nil,
        name_suffix: nil,
        dob: claims[:dob],
        address1: normalize(claims[:address1]),
        address2: nil,
        city: normalize(claims[:city]),
        state: claims[:state],
        zipcode: normalize_zipcode(claims[:zipcode]),
        sex: nil,
        height: nil,
        weight: nil,
        eye_color: nil,
        state_id_number: claims[:state_id_number],
        state_id_jurisdiction: claims[:state_id_jurisdiction] || claims[:state],
        state_id_expiration: claims[:state_id_expiration],
        state_id_issued: claims[:state_id_issued],
        issuing_country_code: 'US',
        document_type_received: 'drivers_license',
      )
    end

    private

    def extract_value(claims_hash, key)
      claims_hash[key]
    end

    def normalize(value)
      return nil if value.blank?
      value.to_s.strip.upcase
    end

    def normalize_zipcode(value)
      return nil if value.blank?
      clean = value.to_s.gsub(/[^0-9]/, '')
      clean[0, 5]
    end
  end
end
