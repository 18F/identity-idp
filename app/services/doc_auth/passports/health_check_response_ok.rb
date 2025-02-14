# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckResponseOk < DocAuth::Response
      def initialize(faraday_response)
        super(
          success: faraday_response.success?,
          extra: { body: faraday_response.body },
        )
      end
    end
  end
end
