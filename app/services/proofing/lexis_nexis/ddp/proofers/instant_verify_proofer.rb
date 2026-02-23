# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Proofers
        class InstantVerifyProofer < Proofing::LexisNexis::Ddp::Proofer
          private

          def build_result_from_response(verification_response)
            parsed_response =
              Proofing::LexisNexis::Ddp::ParsedResponse.new(raw_response(verification_response))
            instant_verify_ddp_product = find_instant_verify_ddp_product(parsed_response)

            Proofing::Resolution::Result.new(
              success: parsed_response.verification_status == 'passed',
              errors: parse_verification_errors(parsed_response),
              exception: nil,
              vendor_name: 'lexisnexis:instant_verify_ddp',
              transaction_id: parsed_response.conversation_id,
              failed_result_can_pass_with_additional_verification:
                failed_result_can_pass_with_additional_verification?(
                  parsed_response,
                  instant_verify_ddp_product,
                ),
              attributes_requiring_additional_verification:
                attributes_requiring_additional_verification(instant_verify_ddp_product),
            )
          end

          def verification_request(applicant)
            Proofing::LexisNexis::Ddp::Requests::InstantVerifyRequest.new(config:, applicant:)
          end

          def find_instant_verify_ddp_product(verification_response)
            return if verification_response.product_list.length > 1
            return if verification_response.product_list.blank?

            product = verification_response.product_list.first
            return unless product['ProductType'] == 'Verify'

            product
          end

          def parse_verification_errors(verification_response)
            errors = Hash.new { |h, k| h[k] = [] }
            verification_response.verification_errors.each do |key, value|
              errors[key] << value
            end
            errors
          end

          # rubocop:disable Layout/LineLength
          def failed_result_can_pass_with_additional_verification?(verification_response, instant_verify_ddp_product)
            return false unless verification_response.verification_status == 'failed'
            return false unless verification_response.transaction_reason_code.match?(/(total|priority)\.scoring\.model\.verification\.fail/)
            return false unless instant_verify_ddp_product.present?
            return false unless instant_verify_ddp_product['ProductStatus'] == 'fail'

            attributes_requiring_additional_verification(instant_verify_ddp_product).any?
          end
          # rubocop:enable Layout/LineLength

          def attributes_requiring_additional_verification(instant_verify_ddp_product)
            Proofing::LexisNexis::InstantVerify::CheckToAttributeMapper
              .new(instant_verify_ddp_product)
              .map_failed_checks_to_attributes
          end

          def raw_response(verification_response)
            verification_response.response_body.dig(
              'integration_hub_results',
              "#{IdentityConfig.store.lexisnexis_threatmetrix_org_id}:#{config.ddp_policy}",
              'Execute Instant Verify', 'tps_vendor_raw_response'
            )
          end
        end
      end
    end
  end
end
