module Proofing
  module LexisNexis
    module InstantVerify
      class Proofer
        attr_reader :config

        def initialize(config)
          @config = LexisNexis::Ddp::Proofer::Config.new(config)
        end

        def proof(applicant)
          response = VerificationRequest.new(config: config, applicant: applicant).send
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          ResolutionResult.new(
            success: false,
            errors: {},
            exception: exception,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        private

        def build_result_from_response(verification_response)
          Proofing::ResolutionResult.new(
            success: verification_response.verification_status == 'passed',
            errors: parse_verification_errors(verification_response),
            exception: nil,
            vendor_name: 'lexisnexis:instant_verify',
            transaction_id: verification_response.conversation_id,
            reference: verification_response.reference,
            failed_result_can_pass_with_additional_verification:
              failed_result_can_pass_with_additional_verification?(verification_response),
            attributes_requiring_additional_verification:
              attributes_requiring_additional_verification(verification_response),
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
        def failed_result_can_pass_with_additional_verification?(verification_response)
          return false unless verification_response.verification_status == 'failed'
          return false unless verification_response.verification_errors.keys.sort == [:"Execute Instant Verify", :base]
          return false unless verification_response.verification_errors[:base].match?(/total\.scoring\.model\.verification\.fail/)
          return false unless attributes_requiring_additional_verification(verification_response).any?
          true
        end
        # rubocop:enable Layout/LineLength

        def attributes_requiring_additional_verification(verification_response)
          CheckToAttributeMapper.new(
            verification_response.verification_errors[:"Execute Instant Verify"],
          ).map_failed_checks_to_attributes
        end
      end
    end
  end
end
