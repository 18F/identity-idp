# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckResponse
      def initialize(faraday_response)
        @faraday_response = faraday_response
      end

      def success?
        case faraday_response
        when Faraday::Response
          faraday_response.success?
        when Faraday::Error
          false
        end
      end

      private

      attr_reader :faraday_response
    end
  end
end
