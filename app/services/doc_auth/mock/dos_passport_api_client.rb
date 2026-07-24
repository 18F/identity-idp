# frozen_string_literal: true

module DocAuth
  module Mock
    class DosPassportApiClient
      def initialize(mock_client_response = nil, id_type: nil)
        @mock_client_response = mock_client_response
      end

      def fetch
        if passport_error?
          DocAuth::Response.new(
            success: false,
            errors: { passport: I18n.t('doc_auth.errors.general.fallback_field_level') },
            extra:,
          )
        elsif network_error?
          DocAuth::Response.new(
            success: false,
            errors: { network: true, passport: true },
            extra:,
          )
        else
          DocAuth::Response.new(success: true, extra:)
        end
      end

      def category
        if id_type == Idp::Constants::DocumentTypes::PASSPORT_CARD
          return :card
        end
        :book
      end

      private

      attr_accessor :mock_client_response

      def passport_error?
        mock_client_response&.passport_check_result&.dig(:PassportCheckResult) == 'Fail'
      end

      def network_error?
        mock_client_response&.passport_check_result&.dig(:NetworkResult) == 'Fail'
      end

      def extra
        {
          vendor_name: 'PassportMock',
        }
      end
    end
  end
end
