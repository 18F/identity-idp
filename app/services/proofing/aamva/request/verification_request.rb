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
      class VerificationRequest
        CONTENT_TYPE = 'application/soap+xml;charset=UTF-8'
        DEFAULT_VERIFICATION_URL =
          'https://verificationservices-cert.aamva.org:18449/dldv/2.1/online'
        SOAP_ACTION =
          '"http://aamva.org/dldv/wsdl/2.1/IDLDVService21/VerifyDriverLicenseData"'

        extend Forwardable

        attr_reader :config, :body, :headers, :url

        def initialize(config:, applicant:, session_id:, auth_token:)
          @config = config
          @applicant = applicant
          @transaction_id = session_id
          @auth_token = auth_token
          @url = verification_url
          @body = build_request_body
          @headers = build_request_headers
        end

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

        private

        attr_reader :applicant, :transaction_id, :auth_token

        def http_client
          Faraday.new(request: { open_timeout: timeout, timeout: timeout }) do |faraday|
            faraday.request :instrumentation, name: 'request_metric.faraday'
            faraday.adapter :net_http
          end
        end

        def add_user_provided_data_to_body
          document = REXML::Document.new(body)
          user_provided_data_map.each do |xpath, data|
            REXML::XPath.first(document, xpath).add_text(data)
          end

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

          if IdentityConfig.store.aamva_send_id_type
            add_state_id_type(
              applicant.state_id_data.state_id_type,
              document,
            )
          end

          @body = document.to_s
        end

        def add_state_id_type(id_type, document)
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

        def build_request_body
          renderer = ERB.new(request_body_template)
          @body = renderer.result(binding)
          add_user_provided_data_to_body
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
            '//nc:IdentificationID' => state_id_number,
            '//aa:MessageDestinationId' => message_destination_id,
            '//nc:PersonGivenName' => applicant.first_name,
            '//nc:PersonSurName' => applicant.last_name,
            '//aa:PersonBirthDate' => applicant.dob,
            '//nc:AddressDeliveryPointText' => applicant.address1,
            '//nc:LocationCityName' => applicant.city,
            '//nc:LocationStateUsPostalServiceCode' => applicant.state,
            '//nc:LocationPostalCode' => applicant.zipcode,
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

        def timeout
          (config.verification_request_timeout || 5).to_f
        end
      end
    end
  end
end
