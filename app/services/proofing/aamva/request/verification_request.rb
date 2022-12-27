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
        CONTENT_TYPE = 'application/soap+xml;charset=UTF-8'.freeze
        DEFAULT_VERIFICATION_URL =
          'https://verificationservices-cert.aamva.org:18449/dldv/2.1/online'.freeze
        SOAP_ACTION =
          '"http://aamva.org/dldv/wsdl/2.1/IDLDVService21/VerifyDriverLicenseData"'.freeze

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
          add_street_address_line_2_to_rexml_document(document) if applicant.address2.present?
          @body = document.to_s
        end

        def add_street_address_line_2_to_rexml_document(document)
          old_address_node = document.delete_element('//ns1:Address')
          new_address_node = old_address_node.clone
          old_address_node.children.each do |child_node|
            next unless child_node.node_type == :element

            new_element = child_node.clone
            new_element.add_text(child_node.text)
            new_address_node.add_element(new_element)

            if child_node.name == 'AddressDeliveryPointText'
              new_address_node.add_element(address_line_2_element)
            end
          end
          REXML::XPath.first(
            document,
            '//ns:verifyDriverLicenseDataRequest',
          ).add_element(new_address_node)
        end

        def address_line_2_element
          element = REXML::Element.new('ns2:AddressDeliveryPointText')
          element.add_text(applicant.address2)
          element
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
            '//ns2:IdentificationID' => state_id_number,
            '//ns1:MessageDestinationId' => message_destination_id,
            '//ns2:PersonGivenName' => applicant.first_name,
            '//ns2:PersonSurName' => applicant.last_name,
            '//ns1:PersonBirthDate' => applicant.dob,
            '//ns2:AddressDeliveryPointText' => applicant.address1,
            '//ns2:LocationCityName' => applicant.city,
            '//ns2:LocationStateUsPostalServiceCode' => applicant.state,
            '//ns2:LocationPostalCode' => applicant.zipcode,
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
