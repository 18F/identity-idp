module Proofing
  module LexisNexis
    module Ddp
      class Proofer
        class << self
          def required_attributes
            [:threatmetrix_session_id,
             :state_id_number,
             :first_name,
             :last_name,
             :dob,
             :ssn,
             :address1,
             :city,
             :state,
             :zipcode,
             :request_ip]
          end

          def vendor_name
            'lexisnexis'
          end

          def optional_attributes
            [:address2, :phone, :email, :uuid_prefix]
          end

          def stage
            :resolution
          end
        end

        attr_reader :config

        def initialize(attrs)
          @config = Config.new(attrs)
        end

        def proof(applicant)
          response = VerificationRequest.new(config: config, applicant: applicant).send
          process_response(response)
          # build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Proofing::Result.new(exception: exception)
        end

        private

        def build_result_from_response(verification_response)
          Proofing::ResolutionResult.new(
            success: verification_response.verification_status == 'passed',
            errors: parse_verification_errors(verification_response),
            exception: nil,
            vendor_name: 'lexisnexis',
            transaction_id: verification_response.conversation_id,
            reference: verification_response.reference,
            failed_result_can_pass_with_additional_verification:
              failed_result_can_pass_with_additional_verification?(verification_response),
            attributes_requiring_additional_verification:
              attributes_requiring_additional_verification(verification_response),
            vendor_workflow: config.phone_finder_workflow,
            drivers_license_check_info: drivers_license_check_info(verification_response),
          )
        end

        def parse_verification_errors(verification_response)
          errors = Hash.new { |h, k| h[k] = [] }
          verification_response.verification_errors.each do |key, value|
            errors[key] << value
          end
          errors
        end

        def process_response(response)
          result = Proofing::Result.new
          body = response.response_body

          result.response_body = body
          result.transaction_id = body['request_id']
          request_result = body['request_result']
          review_status = body['review_status']

          result.review_status = review_status
          result.add_error(:request_result, request_result) unless request_result == 'success'
          result.add_error(:review_status, review_status) unless review_status == 'pass'

          result
        end
      end
    end
  end
end
