module Proofing
  module LexisNexis
    module PhoneFinder
      class Proofer
        attr_reader :config

        def initialize(config)
          @config = LexisNexis::Ddp::Proofer::Config.new(config)
        end

        def proof(applicant)
          response = VerificationRequest.new(config: config, applicant: applicant).send
          return build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          AddressResult.new(
            success: false,
            errors: {},
            exception: exception,
            vendor_name: 'lexisnexis:phone_finder',
          )
        end

        private

        def build_result_from_response(verification_response)
          AddressResult.new(
            success: verification_response.verification_status == 'passed',
            errors: parse_verification_errors(verification_response),
            exception: nil,
            vendor_name: 'lexisnexis:phone_finder',
            transaction_id: verification_response.conversation_id,
            reference: verification_response.reference,
          )
        end

        def parse_verification_errors(verification_response)
          errors = Hash.new { |h, k| h[k] = [] }
          verification_response.verification_errors.each do |key, value|
            errors[key] << value
          end
          errors
        end
      end
    end
  end
end
