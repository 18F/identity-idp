# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckResponse < DocAuth::Response
      def initialize(faraday_response)
        @faraday_response = faraday_response

        super(
          success:,
          errors:, 
          exception:,
          extra: extra_values,
        )
      end

      private

      def success
        case faraday_response
        when Faraday::Response
          faraday_response.success?
        when Faraday::Error
          false
        end
      end

      def errors
        case faraday_response
        when Faraday::Response
          {}
        when Faraday::Error
          { network: faraday_response.response_status || true }
        end
      end

      def exception
        if faraday_response.is_a?(Faraday::Error)
          faraday_response
        else
          nil
        end
      end

      def extra_values
        { body: faraday_response.body } if faraday_response.respond_to?(:body)
      end

      attr_reader :faraday_response
    end
  end
end
