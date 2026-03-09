# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Responses
        class PhoneRiskResponse < Proofing::Socure::IdPlus::Response
          def to_h
            {
              phonerisk: {
                reason_codes: SocureReasonCode.with_definitions(phonerisk_reason_codes),
                score: phonerisk_score,
                signals: phonerisk_signals,
              },
              name_phone_correlation: {
                reason_codes: SocureReasonCode
                  .with_definitions(name_phone_correlation_reason_codes),
                score: name_phone_correlation_score,
              },
              customer_user_id:,
            }
          end

          def successful?
            name_correlation_successful? && phonerisk_successful? && !has_autofail_reason_codes?
          end

          private

          attr_reader :http_response

          def phonerisk
            phonerisk_object = http_response.body['phoneRisk']
            raise 'No phonerisk section on response' unless phonerisk_object
            phonerisk_object
          end

          def name_phone_correlation
            name_phone_correlation_object = http_response.body['namePhoneCorrelation']
            raise 'No namePhoneCorrelation section on response' unless name_phone_correlation_object
            name_phone_correlation_object
          end

          def phonerisk_successful?
            phonerisk_score < phonerisk_score_threshold
          end

          def name_correlation_successful?
            name_correlation_score_threshold < name_phone_correlation_score
          end

          def phonerisk_score
            phonerisk.dig('score')
          end

          def phonerisk_reason_codes
            phonerisk.dig('reasonCodes')
          end

          def phonerisk_signals
            phonerisk.dig('signals')
          end

          def name_phone_correlation_score
            name_phone_correlation.dig('score')
          end

          def name_phone_correlation_reason_codes
            name_phone_correlation.dig('reasonCodes')
          end

          def name_correlation_score_threshold
            IdentityConfig.store.idv_socure_phonerisk_name_correlation_score_threshold
          end

          def phonerisk_score_threshold
            IdentityConfig.store.idv_socure_phonerisk_score_threshold
          end

          def has_autofail_reason_codes?
            (phonerisk_reason_codes & auto_failure_reason_codes).any? ||
              (name_phone_correlation_reason_codes & auto_failure_reason_codes).any?
          end

          def auto_failure_reason_codes
            IdentityConfig.store.idv_socure_phonerisk_auto_failure_reason_codes
          end
        end
      end
    end
  end
end
