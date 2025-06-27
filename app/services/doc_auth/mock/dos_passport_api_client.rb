# frozen_string_literal: true

module DocAuth
  module Mock
    class DosPassportApiClient
      def initialize(mock_client_response = nil)
        @mock_client_response = mock_client_response
      end

      def fetch
        if mock_client_response&.passport_check_result&.dig(:PassportCheckResult) == 'Fail'
          DocAuth::Response.new(
            success: false,
            errors: { passport: I18n.t('doc_auth.errors.general.fallback_field_level') },
          )
        else
          DocAuth::Response.new(success: true)
        end
      end

      private

      attr_accessor :mock_client_response
    end
  end
end
