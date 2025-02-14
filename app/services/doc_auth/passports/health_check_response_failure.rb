# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckResponseFailure < DocAuth::Response 
     def initialize(faraday_error)
        errors =
          if faraday_error.respond_to?(:status) # some subclasses don't
            { network: faraday_error.status }
          else
            { network: true }
          end

        super(
          success: false,
          errors:,
          exception: faraday_error,
        )
      end
    end
  end
end
