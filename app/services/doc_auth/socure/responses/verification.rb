# frozen_string_literal: true

module DocAuth
  module Socure
    module Responses
      class Verification < DocAuth::Response
        include DocPiiReader
        # include ClassificationConcern

        attr_reader :verification_data

        def initialize(verification_data)
          @verification_data = verification_data
          @liveness_checking_enabled = false
          @pii_from_doc = read_pii(verification_data)
          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
            pii_from_doc: @pii_from_doc,
          )
        rescue StandardError => e
          NewRelic::Agent.notice_error(e)
          super(
            success: false,
            errors: { network: true },
            exception: e,
            extra: {
              backtrace: e.backtrace,
              reference: verification_data['referenceId'],
            },
          )
        end

        def successful_result?
          doc_auth_success?
        end

        def doc_auth_success?
          return false unless id_type_supported?

          verification_data.dig('decision', 'value') == 'accept'
        end

        def error_messages
          return {} if successful_result?

          { reason_codes: verification_data['reasonCodes'] }
        end

        def extra_attributes
          verification_data.except('documentData')
        end

        def attention_with_barcode?
          false
        end

        def billed?
          true # tbd
        end

        private

        # def document_verification_data
        #   payload.dig('data', 'documentVerification') || payload.dig('documentVerification')
        # end

        def id_type_supported?
          true # tbd
        end
      end
    end
  end
end
