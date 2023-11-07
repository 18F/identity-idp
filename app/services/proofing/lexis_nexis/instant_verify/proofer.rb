module Proofing
  module LexisNexis
    module InstantVerify
      class Proofer
        attr_reader :config

        def initialize(config)
          @config = LexisNexis::Config.new(config)
        end

        def proof(applicant)
          response = VerificationRequest.new(config:, applicant:).send_request
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Resolution::Result.new(
            success: false, errors: {}, exception:,
            vendor_name: 'lexisnexis:instant_verify',
            vendor_workflow: config.instant_verify_workflow
          )
        end

        private

        def build_result_from_response(verification_response)
          instant_verify_product = find_instant_verify_product(verification_response)

          Proofing::Resolution::Result.new(
            success: verification_response.verification_status == 'passed',
            errors: parse_verification_errors(verification_response),
            exception: nil,
            vendor_name: 'lexisnexis:instant_verify',
            transaction_id: verification_response.conversation_id,
            reference: verification_response.reference,
            failed_result_can_pass_with_additional_verification:
              failed_result_can_pass_with_additional_verification?(
                verification_response,
                instant_verify_product,
              ),
            attributes_requiring_additional_verification:
              attributes_requiring_additional_verification(instant_verify_product),
            vendor_workflow: config.instant_verify_workflow,
          )
        end

        def parse_verification_errors(verification_response)
          errors = Hash.new { |h, k| h[k] = [] }
          verification_response.verification_errors.each do |key, value|
            errors[key] << value
          end
          errors
        end

        # rubocop:disable Layout/LineLength
        def failed_result_can_pass_with_additional_verification?(verification_response, instant_verify_product)
          return false unless verification_response.verification_status == 'failed'
          return false unless verification_response.transaction_reason_code.match?(/(total|priority)\.scoring\.model\.verification\.fail/)
          return false unless instant_verify_product.present?
          return false unless instant_verify_product['ProductStatus'] == 'fail'
          return false unless attributes_requiring_additional_verification(instant_verify_product).any?
          true
        end
        # rubocop:enable Layout/LineLength

        def attributes_requiring_additional_verification(instant_verify_product)
          CheckToAttributeMapper.new(instant_verify_product).map_failed_checks_to_attributes
        end

        def find_instant_verify_product(verification_response)
          return if verification_response.product_list.length > 1
          return if verification_response.product_list.blank?

          product = verification_response.product_list.first
          return unless product['ProductType'] == 'InstantVerify'

          product
        end
      end
    end
  end
end
