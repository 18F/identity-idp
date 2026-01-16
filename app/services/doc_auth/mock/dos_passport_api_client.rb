# frozen_string_literal: true

module DocAuth
  module Mock
    class DosPassportApiClient
      def initialize(mock_client_response = nil)
        @mock_client_response = mock_client_response
      end

      def fetch
        if passport_error?
          DocAuth::Response.new(
            success: false,
            errors: { passport: I18n.t('doc_auth.errors.general.fallback_field_level') },
          )
        elsif network_error?
          DocAuth::Response.new(
            success: false,
            errors: { network: true, passport: true },
          )
        else
          DocAuth::Response.new(success: true)
        end
      end

      private

      attr_accessor :mock_client_response

      def passport_error?
        mock_client_response&.passport_check_result&.dig(:PassportCheckResult) == 'Fail'
      end

      def network_error?
        mock_client_response&.passport_check_result&.dig(:NetworkResult) == 'Fail'
      end
    end
  end
end
