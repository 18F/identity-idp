# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Responses
      class TrueIdResponse < LexisNexisResponse
        def initialize(http_response, liveness_checking_enabled)
          @liveness_checking_enabled = liveness_checking_enabled

          super http_response
        end

        def successful_result?
          transaction_status_passed? &&
            product_status_passed? &&
            doc_auth_result_passed?
        end

        def error_messages
          return {} if successful_result?

          response_error_info = {
            ConversationId: conversation_id,
            Reference: reference,
            Product: 'TrueID',
            TransactionReasonCode: transaction_reason_code,
            DocAuthResult: doc_auth_result,
            Alerts: parse_alerts,
            PortraitMatchResults: true_id_product[:PORTRAIT_MATCH_RESULT]
          }

          ErrorGenerator.generate_trueid_errors(response_error_info, liveness_checking_enabled)
        end

        def extra_attributes
          true_id_product[:AUTHENTICATION_RESULT].reject do |k, _v|
            PII_DETAILS.include? k
          end
        end

        def pii_from_doc
          true_id_product[:AUTHENTICATION_RESULT].select do |k, _v|
            PII_DETAILS.include? k
          end
        end

        private

        def product_status_passed?
          product_status == 'pass'
        end

        def doc_auth_result_passed?
          doc_auth_result == 'Passed'
        end

        def doc_auth_result
          true_id_product.dig(:AUTHENTICATION_RESULT, :DocAuthResult)
        end

        def product_status
          true_id_product.dig(:ProductStatus)
        end

        def true_id_product
          products[:TrueID]
        end

        def parse_alerts
          new_alerts = []
          all_alerts = true_id_product[:AUTHENTICATION_RESULT].select { |key| key.start_with?('Alert_')  }
          alert_names = all_alerts.select { |key| key.end_with?('_AlertName') }

          # Make the assumption that every alert will have an *_AlertName associated with it
          alert_names.each do |key, value|
            new_set = {}
            alert_value = key.scan(/Alert_\d{1,2}_/).first

            # Get the set of Alerts that are all the same number (e.g. Alert_11) so we can pull the values together
            alert_set = all_alerts.select { |key| key.match?(alert_value) }

            alert_set.each do |key, value|
              new_set[:alert] = alert_value.delete_suffix('_')
              new_set[:name] = value if key.end_with?('_AlertName')
              new_set[:result] = value if key.end_with?('_AuthenticationResult')
              new_set[:region] = value if key.end_with?('_Regions')
            end

            new_alerts.push(new_set)
          end
          new_alerts
        end

        def detail_groups
          %w[
            AUTHENTICATION_RESULT
            IDAUTH_FIELD_DATA
            IDAUTH_FIELD_NATIVE_DATA
            IMAGE_METRICS_RESULT
            PORTRAIT_MATCH_RESULT
          ].freeze
        end
      end
    end
  end
end
