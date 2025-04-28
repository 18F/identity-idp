# frozen_string_literal: true

module DocAuth
  module Mock
    class DosPassportApiClient
      def initialize(lexis_nexis_response)
        @lexis_nexis_response = lexis_nexis_response
      end

      def fetch
        if lexis_nexis_response&.passport_check_result&.dig(:PassportCheckResult) == 'Fail'
          DocAuth::Response.new(
            success: false,
            errors: { passport: 'invalid MRZ' },
          )
        else
          DocAuth::Response.new(success: true)
        end
      end

      private

      attr_accessor :lexis_nexis_response
    end
  end
end
