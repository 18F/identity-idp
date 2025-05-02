# frozen_string_literal: true

require 'erb'
require 'faraday'
require 'rexml/document'
require 'rexml/xpath'
require 'securerandom'
require 'retries'

module Proofing
  module Aamva
    module Request
      RequestAttribute = Data.define(:xpath, :required).freeze
      class VerificationRequest
        CONTENT_TYPE = 'application/soap+xml;charset=UTF-8'
        DEFAULT_VERIFICATION_URL =
          'https://verificationservices-cert.aamva.org:18449/dldv/2.1/online'
        SOAP_ACTION =
          '"http://aamva.org/dldv/wsdl/2.1/IDLDVService21/VerifyDriverLicenseData"'

        VERIFICATION_REQUESTED_ATTRS = {
          first_name: RequestAttribute.new(xpath: '//nc:PersonGivenName', required: true),
          middle_name: RequestAttribute.new(xpath: '//nc:PersonMiddleName', required: false),
          last_name: RequestAttribute.new('//nc:PersonSurName', true),
          name_suffix: RequestAttribute.new('//nc:PersonNameSuffixText', false),
          dob: RequestAttribute.new('//aa:PersonBirthDate', true),
          address1: RequestAttribute.new('//nc:AddressDeliveryPointText', true),
          address2: RequestAttribute.new('//nc:AddressDeliveryPointText[2]', false),
          city: RequestAttribute.new('//nc:LocationCityName', true),
          state: RequestAttribute.new('//nc:LocationStateUsPostalServiceCode', true),
          zipcode: RequestAttribute.new('//nc:LocationPostalCode', true),
          state_id_number: RequestAttribute.new('//nc:IdentificationID', true),
          id_doc_type: RequestAttribute.new('//aa:DocumentCategoryCode', false),
          state_id_expiration: RequestAttribute.new('//aa:DriverLicenseExpirationDate', false),
          state_id_jurisdiction: RequestAttribute.new('//aa:MessageDestinationId', true),
          state_id_issued: RequestAttribute.new('//aa:DriverLicenseIssueDate', false),
          eye_color: RequestAttribute.new('//aa:PersonEyeColorCode', false),
          height: RequestAttribute.new('//aa:PersonHeightMeasure', false),
          sex: RequestAttribute.new('//aa:PersonSexCode', false),
          weight: RequestAttribute.new('//aa:PersonWeightMeasure', false),
        }.freeze

        extend Forwardable

        attr_reader :config, :body, :headers, :url

        # @param applicant [Proofing::Aamva::Applicant]
        def initialize(config:, applicant:, session_id:, auth_token:)
          @config = config
          @applicant = applicant
          @transaction_id = session_id
          @auth_token = auth_token
          @requested_attributes = {}
          @url = verification_url
          @body = build_request_body
          @headers = build_request_headers
        end

        # @return [Proofing::Aamva::Response::VerificationResponse]
        def send
          Response::VerificationResponse.new(
            http_client.post(url, body, headers) do |req|
              req.options.context = { service_name: 'aamva_verification' }
            end,
          )
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => err
          message = "AAMVA raised #{err.class} waiting for verification response: #{err.message}"
          raise ::Proofing::TimeoutError, message
        end

        def verification_url
          config.verification_url || DEFAULT_VERIFICATION_URL
        end

        # The requested attributes in the applicant PII hash. Values are:
        # - +:present+ - value present
        # - +:missing+ - field is required, but value was blank
        #
        # @see Proofing::Aamva::Applicant#from_proofer_applicant for fields
        # @return [Hash{Symbol => Symbol}]
        def requested_attributes
          { **@requested_attributes }
        end

        private

        # @return [Proofing::Aamva::Applicant]
        attr_reader :applicant
        attr_reader :transaction_id, :auth_token

        def http_client
          Faraday.new(request: { open_timeout: timeout, timeout: timeout }) do |faraday|
            faraday.request :instrumentation, name: 'request_metric.faraday'
            faraday.adapter :net_http
          end
        end

        def add_user_provided_data_to_body(body)
          document = REXML::Document.new(body)
          user_provided_data_map.each do |attribute, data|
            xpath = VERIFICATION_REQUESTED_ATTRS[attribute].xpath
            REXML::XPath.first(document, xpath).add_text(data)
          end

          add_optional_element(
            'nc:PersonMiddleName',
            value: applicant.middle_name,
            document:,
            inside: '//nc:PersonName',
          )

          add_optional_element(
            'nc:PersonNameSuffixText',
            value: applicant.name_suffix,
            document:,
            inside: '//nc:PersonName',
          )

          add_optional_element(
            'aa:PersonHeightMeasure',
            value: applicant.height,
            document:,
            inside: '//dldv:verifyDriverLicenseDataRequest',
          )

          add_optional_element(
            'aa:PersonWeightMeasure',
            value: applicant.weight,
            document:,
            inside: '//dldv:verifyDriverLicenseDataRequest',
          )

          add_optional_element(
            'aa:PersonEyeColorCode',
            value: applicant.eye_color,
            document:,
            inside: '//dldv:verifyDriverLicenseDataRequest',
          )

          add_sex_code(applicant.sex, document)

          add_optional_element(
            'nc:AddressDeliveryPointText',
            value: applicant.address2,
            document:,
            after: '//aa:Address/nc:AddressDeliveryPointText',
          )

          add_optional_element(
            'aa:DriverLicenseIssueDate',
            value: applicant.state_id_data.state_id_issued,
            document:,
            inside: '//dldv:verifyDriverLicenseDataRequest',
          )

          add_optional_element(
            'aa:DriverLicenseExpirationDate',
            value: applicant.state_id_data.state_id_expiration,
            document:,
            inside: '//dldv:verifyDriverLicenseDataRequest',
          )

          add_id_doc_type(
            applicant.state_id_data.id_doc_type,
            document,
          )

          update_requested_attributes(document)
          document.to_s
        end

        def add_id_doc_type(id_type, document)
          category_code = case id_type
                            when 'drivers_license'
                              1
                            when 'drivers_permit'
                              2
                            when 'state_id_card'
                              3
                          end

          if category_code
            add_optional_element(
              'aa:DocumentCategoryCode',
              value: category_code,
              document:,
              inside: '//dldv:verifyDriverLicenseDataRequest',
            )
          end
        end

        def add_sex_code(sex_value, document)
          sex_code = case sex_value
                       when 'male'
                         1
                       when 'female'
                         2
                     end

          if sex_code
            add_optional_element(
              'aa:PersonSexCode',
              value: sex_code,
              document:,
              inside: '//dldv:verifyDriverLicenseDataRequest',
            )
          end
        end

        def add_optional_element(name, value:, document:, inside: nil, after: nil)
          return if value.blank?

          el = REXML::Element.new(name)
          el.text = value

          if inside
            REXML::XPath.first(document, inside).add_element(el)
          elsif after
            sibling = REXML::XPath.first(document, after)
            sibling.parent.insert_after(sibling, el)
          end
        end

        # @param document [REXML::Document]
        def update_requested_attributes(document)
          VERIFICATION_REQUESTED_ATTRS.each do |attribute, rule|
            value = REXML::XPath.first(document, rule.xpath)&.text
            if value.present?
              @requested_attributes[attribute] = :present
            elsif rule.required
              @requested_attributes[attribute] = :missing
            end
          end
        end

        def build_request_body
          renderer = ERB.new(request_body_template)
          tmp_body = renderer.result(binding)
          add_user_provided_data_to_body(tmp_body)
        end

        def build_request_headers
          {
            'SOAPAction' => SOAP_ACTION,
            'Content-Type' => CONTENT_TYPE,
            'Content-Length' => body.length.to_s,
          }
        end

        def message_destination_id
          # Note: AAMVA uses this field to route the request to the appropriate state DMV.
          #       We are required to use 'P6' as the jurisdiction when we make requests
          #       in the AAMVA CERT/Test environment.
          return 'P6' if config.cert_enabled.to_s == 'true'
          applicant.state_id_data.state_id_jurisdiction
        end

        def request_body_template
          template_file_path = Rails.root.join(
            'app',
            'services',
            'proofing',
            'aamva',
            'request',
            'templates',
            'verify.xml.erb',
          )
          File.read(template_file_path)
        end

        def transaction_locator_id
          applicant.uuid
        end

        def user_provided_data_map
          {
            state_id_number:,
            state_id_jurisdiction: message_destination_id,
            first_name: applicant.first_name,
            last_name:,
            dob: applicant.dob,
            address1: applicant.address1,
            city: applicant.city,
            state: applicant.state,
            zipcode: applicant.zipcode,
          }
        end

        def state_id_number
          case applicant.state_id_data.state_id_jurisdiction
            when 'SC'
              applicant.state_id_data.state_id_number.rjust(8, '0')
            else
              applicant.state_id_data.state_id_number
          end
        end

        def last_name
          if IdentityConfig.store.idv_aamva_split_last_name_states
              .include? applicant.state_id_data.state_id_jurisdiction
            applicant.last_name.split(' ').first
          else
            applicant.last_name
          end
        end

        def timeout
          (config.verification_request_timeout || 5).to_f
        end
      end
    end
  end
end
