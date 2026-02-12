# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      module Ddp
        class TrueIdResponse < DocAuth::Response
          include ImageMetricsReader
          include DocAuth::LexisNexis::Responses::TrueIdResponseConcern
          include DocAuth::LexisNexis::DocPiiReader
          include DocAuth::ClassificationConcern

          attr_reader :config, :http_response, :passport_requested

          def initialize(http_response:, config:, passport_requested: false,
                         liveness_checking_enabled: false, request_context: {}, request: nil)
            @config = config
            @http_response = http_response
            @passport_requested = passport_requested
            @request_context = request_context
            @request = request
            @liveness_checking_enabled = liveness_checking_enabled
            @pii_from_doc = read_pii
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

          # returns full check success status, considering all checks:
          # vendor (document and selfie if requested)
          # Will be further implemented in future tickets
          def successful_result?
            return false if passport_card_detected?

            doc_auth_success?
          end

          def doc_auth_success?
            transaction_status_passed? && id_type_supported? && expected_document_type_received?
          end

          # To be implemented in LG-17088
          def error_messages
            return {} if successful_result?

            if passport_card_detected?
              { passport_card: I18n.t('doc_auth.errors.doc.doc_type_check') }
            elsif id_type.present? && !expected_document_type_received?
              { unexpected_id_type: true, expected_id_type: expected_id_type }
            elsif with_authentication_result?
              ErrorGenerator.new(config).generate_doc_auth_errors(response_info)
            elsif true_id_product.present?
              ErrorGenerator.wrapped_general_error
            else
              { network: true } # return a generic technical difficulties error to user
            end
          end

          def extra_attributes
            if with_authentication_result?
              attrs = response_info.merge(true_id_product[:AUTHENTICATION_RESULT])
              attrs.reject! do |k, _v|
                PII_EXCLUDES.include?(k) || k.start_with?('Alert_')
              end
            else
              # This branch is currently never reached by tests as all DDP response fixtures include
              # AUTHENTICATION_RESULT somewhere in their structure.
              #
              # RDP does test the fixture true_id_response_failure_empty which does not include
              # AUTHENTICATION_RESULT.
              #
              # DDP may need a new fixture that correlates to this RDP fixture in order to better
              # test this branch.
              attrs = {
                lexis_nexis_status: parsed_response_body[:Status],
                lexis_nexis_info: parsed_response_body.dig(:Information),
                exception: 'LexisNexis Response Unexpected: TrueID DDP response details not found.',
              }
            end

            basic_logging_info.merge(attrs)
          end

          private

          def products
            @products ||=
              raw_response.dig(:Products)&.each_with_object({}) do |product, product_list|
                extract_details(product)
                product_list[product[:ProductType]] = product
              end&.with_indifferent_access
          end

          def raw_response
            parsed_response_body.dig(
              :integration_hub_results,
              "#{IdentityConfig.store.lexisnexis_threatmetrix_org_id}:#{policy}",
              'Authentication', 'tps_vendor_raw_response'
            )
          end

          def policy
            @policy ||= @request&.policy
          end

          def expected_document_type_received?
            expected_id_types = passport_requested ?
              Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES :
              Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES

            expected_id_types.include?(id_type)
          end

          def id_type
            pii_from_doc&.document_type_received
          end

          def passport_pii?
            @passport_pii ||=
              Idp::Constants::DocumentTypes::PASSPORT_TYPES.include?(id_type)
          end

          def transaction_status
            raw_response&.dig(:Status, :TransactionStatus)
          end

          def transaction_status_passed?
            transaction_status == 'passed'
          end

          def reference
            @reference ||= parsed_response_body.dig(:Status, :Reference)
          end

          def classification_info
            # Acuant response has both sides info, here simulate that
            classification_hash = {
              Front: {
                ClassName: doc_class_name,
                CountryCode: issuing_country_code,
              },
            }
            if !passport_pii?
              classification_hash[:Back] = {
                ClassName: doc_class_name, # document_type_received_slug,
                CountryCode: issuing_country_code,
              }
            end
            classification_hash
          end

          def transaction_reason_code
            @transaction_reason_code ||=
              parsed_response_body.dig(:Status, :TransactionReasonCode, :Code)
          end

          def product_status
            true_id_product&.dig(:ProductStatus)
          end

          def decision_product_status
            true_id_product_decision&.dig(:ProductStatus)
          end

          def true_id_product_decision
            products&.dig(:TrueID_Decision)
          end

          def portrait_match_results
            true_id_product&.dig(:PORTRAIT_MATCH_RESULT)
          end

          def conversation_id
            @conversation_id ||= parsed_response_body.dig(:Status, :ConversationId)
          end

          def request_id
            @request_id ||= parsed_response_body.dig(:Status, :RequestId)
          end

          def doc_auth_result
            true_id_product&.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
          end

          def billed?
            !!doc_auth_result
          end

          def review_status
            parsed_response_body[:review_status]
          end

          def basic_logging_info
            {
              conversation_id: conversation_id,
              request_id: request_id,
              reference: reference,
              review_status: review_status,
              vendor: 'TrueID DDP',
              billed: billed?,
              workflow: @request_context&.dig(:workflow),
            }
          end
        end
      end
    end
  end
end
