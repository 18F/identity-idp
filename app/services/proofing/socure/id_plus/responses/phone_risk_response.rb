# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Responses
        class PhoneRiskResponse < Proofing::Socure::IdPlus::Response
          def to_h
            { phonerisk:, name_phone_correlation:, customer_user_id: }
          end

          def successful?
            name_correlation_successful? && phonerisk_successful?
          end

          def verified_attributes
            result = []
            result = %i[first_name last_name] if name_phone_correlation_score
            result << :phone if phonerisk_score
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
            phonerisk_score < IdentityConfig.store.idv_socure_phonerisk_score_threshold
          end

          def name_correlation_successful?
            IdentityConfig.store.idv_socure_phonerisk_name_correlation_score_threshold < name_phone_correlation_score
          end

          def phonerisk_score
            phonerisk.dig('score')
          end

          def name_phone_correlation_score
            name_phone_correlation.dig('score')
          end
        end
      end
    end
  end
end
