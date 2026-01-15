# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      module Ddp
        class TrueIdResponse < DocAuth::Response
          include ImageMetricsReader
          include DocPiiReader

          attr_reader :config, :http_response, :passport_requested

          def initialize(http_response:, config:, passport_requested: false,
                         liveness_checking_enabled: false, request_context: {})
            @config = config
            @http_response = http_response
            @passport_requested = passport_requested
            @request_context = request_context
            @liveness_checking_enabled = liveness_checking_enabled
            @pii_from_doc = nil # To be done in LG-17904
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
                reference: reference,
              },
            )
          end

          ## returns full check success status, considering all checks:
          #  vendor (document and selfie if requested)
          #  Will be further implemented in future tickets
          def successful_result?
            doc_auth_success?
          end

          def doc_auth_success?
            # To be further implemented in LG-17090 and LG-17091
            transaction_status_passed? # && id_type_supported? && expected_document_type_received?
          end

          # To be implemented in LG-17088
          def error_messages
            successful_result? ? {} : { network: true }
          end

          # To be implemented in LG-17089
          def extra_attributes
            return {}
          end

          private

          def parsed_response_body
            @parsed_response_body ||= JSON.parse(http_response.body).with_indifferent_access
          end

          def authentication_results
            parsed_response_body.dig(
              :integration_hub_results, 'dvxavi11:default_auth_policy_pm',
              'Authentication - With PM', 'tps_vendor_raw_response'
            )
          end

          def transaction_status
            authentication_results&.dig(:Status, :TransactionStatus)
          end

          def transaction_status_passed?
            transaction_status == 'passed'
          end

          def reference
            @reference ||= parsed_response_body.dig(:Status, :Reference)
          end
        end
      end
    end
  end
end
