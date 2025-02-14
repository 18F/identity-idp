# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckResponse
      delegate :success?, to: :@faraday_response

      def initialize(faraday_response)
        @faraday_response = faraday_response
      end
    end
  end
end
