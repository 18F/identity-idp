# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Responses
        class PhoneRiskResponse < Proofing::Socure::IdPlus::Response
          def phonerisk_reason_codes
            @phonerisk_reason_codes ||= phonerisk.dig('reasonCodes').to_set.freeze
          end

          def phonerisk_score
            @phonerisk_score ||= phonerisk.dig('score')
          end

          def name_phone_correlation_reason_codes
            @name_phone_correlation_reason_codes ||= name_phone_correlation.dig('reasonCodes').to_set.freeze
          end

          def name_phone_correlation_score
            @name_phone_correlation_score ||= name_phone_correlation.dig('score')
          end

          def to_h
            { phonerisk:, name_phone_correlation: }
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
        end
      end
    end
  end
end
