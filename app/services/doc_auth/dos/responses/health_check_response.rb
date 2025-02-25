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
          parsed_body[:status].to_s.downcase == 'up'
        end

        def extra
          {
            body: body,
          }
        end

        def body
          faraday_response&.respond_to?(:body) && faraday_response.body
        end

        def parsed_body
          JSON.parse(body, symbolize_names: true)
        end

        def errors
          if faraday_error?
            {
              network: faraday_response.response_status,
            }
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
