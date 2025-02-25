# frozen_string_literal: true

module DocAuth
  module Dos
    module Responses
      class HealthCheckResponse < DocAuth::Response
        attr_accessor :faraday_response

        def initialize(faraday_response:)
          @faraday_response = faraday_response

          super(
            success:,
            extra:,
            errors:,
            exception:,
          )
        end

        def success
          return false if faraday_error?
          return false if !parsed_body
          parsed_body[:status].to_s.downcase == 'up'
        end

        def extra
          {
            body: body,
          }
        end

        def body
          return faraday_response.response_body if faraday_response.respond_to?(:response_body)
          return faraday_response.env.response_body if faraday_response.respond_to?(:env)
        end

        def parsed_body
          body && JSON.parse(body, symbolize_names: true)
        end

        def errors
          if faraday_error?
            if faraday_response&.response_status
              {
                network: faraday_response.response_status,
              }
            else
              { network: 'faraday exception' }
            end
          else
            {}
          end
        end

        def exception
          if faraday_response.is_a?(Faraday::Error)
            faraday_response.inspect
          end
        end

        def faraday_error?
          faraday_response.is_a?(Faraday::Error)
        end
      end
    end
  end
end
