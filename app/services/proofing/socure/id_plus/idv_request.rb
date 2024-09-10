# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class IdvRequest < Request
        attr_reader :config, :input

        # @param [Proofing::Socure::IdPlus::Config] config
        # @param [Proofing::Socure::IdPlus::Input] input
        def initialize(config:, input:)
          @config = config
          @input = input
        end

        def send_request
          conn = Faraday.new do |f|
            f.request :instrumentation, name: 'request_metric.faraday'
            f.response :raise_error
            f.response :json
            f.options.timeout = config.timeout
            f.options.read_timeout = config.timeout
            f.options.open_timeout = config.timeout
            f.options.write_timeout = config.timeout
          end

          result = conn.post(url, body, headers) do |req|
            req.options.context = { service_name: SERVICE_NAME }
          end

          Response.new(result)

        rescue Faraday::BadRequestError,
               Faraday::ConnectionFailed,
               Faraday::ServerError,
               Faraday::SSLError,
               Faraday::TimeoutError,
               Faraday::UnauthorizedError => e

          if timeout_error?(e)
            raise ::Proofing::TimeoutError,
                  'Timed out waiting for verification response'
          end

          raise RequestError, e
        end

        def body
          @body ||= {
            modules: ['kyc'],
            firstName: input.first_name,
            surName: input.last_name,
            country: 'US',

            physicalAddress: input.address1,
            physicalAddress2: input.address2,
            city: input.city,
            state: input.state,
            zip: input.zipcode,

            nationalId: input.ssn,
            dob: input.dob&.to_date&.to_s,

            userConsent: true,
            consentTimestamp: 5.minutes.ago.iso8601,

            email: input.email,
            mobileNumber: input.phone,

            # > The country or jurisdiction from where the transaction originates,
            # > specified in ISO-2 country codes format
            countryOfOrigin: 'US',
          }.to_json
        end

        def headers
          @headers ||= {
            'Content-Type' => 'application/json',
            'Authorization' => "SocureApiKey #{config.api_key}",
          }
        end

        def url
          @url ||= URI.join(
            config.base_url,
            '/api/3.0/EmailAuthScore',
          ).to_s
        end

        private

        # @param [Faraday::Error] err
        def faraday_error_message(err)
          message = begin
            err.response[:body].dig('msg')
          rescue
            'HTTP request failed'
          end

          status = begin
            err.response[:status]
          rescue
            'unknown status'
          end

          "#{message} (#{status})"
        end
      end
    end
  end
end
