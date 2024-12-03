# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Request
        class Error < StandardError
          def initialize(wrapped)
            @wrapped = wrapped
            super(build_message)
          end

          def reference_id
            return @reference_id if defined?(@reference_id)
            @reference_id = response_body.is_a?(Hash) ?
              response_body['referenceId'] :
              nil
          end

          def response_body
            return @response_body if defined?(@response_body)
            @response_body = wrapped.try(:response_body)
          end

          def response_status
            return @response_status if defined?(@response_status)
            @response_status = wrapped.try(:response_status)
          end

          private

          attr_reader :wrapped

          def build_message
            message = response_body.is_a?(Hash) ? response_body['msg'] : nil
            message ||= wrapped.message
            status = response_status ? " (#{response_status})" : ''
            [message, status].join('')
          end
        end

        attr_reader :config, :input

        SERVICE_NAME = 'socure_id_plus'

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
          end

          Response.new(
            conn.post(url, body, headers) do |req|
              req.options.context = { service_name: SERVICE_NAME }
            end,
          )
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

          raise Error, e
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
            consentTimestamp: input.consent_given_at&.to_time&.iso8601,

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

        def timeout_error?(err)
          err.is_a?(Faraday::TimeoutError) ||
            (err.is_a?(Faraday::ConnectionFailed) && err.wrapped_exception.is_a?(Net::OpenTimeout))
        end
      end
    end
  end
end
