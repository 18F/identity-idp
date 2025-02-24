# frozen_string_literal: true

module DocAuth
  module Dos
    module Responses
      class HealthCheckFailure < DocAuth::Response
        def initialize(faraday_error: nil)
          @faraday_error = faraday_error

          super(
            success: false,
            errors:,
            exception: faraday_error.inspect,
            extra: { body: },
          )
        end

        private

        attr_accessor :faraday_error

        def response
          faraday_error.respond_to?(:response) && faraday_error.response
        end

        def errors
          if response
            { network: response[:status] }
          else
            { network: 'faraday exception' }
          end
        end

        def body
          if response
            response[:body]
          else
            {}
          end
        end
      end
    end
  end
end
