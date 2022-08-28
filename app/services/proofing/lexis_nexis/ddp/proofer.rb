module Proofing
  module LexisNexis
    module Ddp
      class Proofer < LexisNexis::Proofer
        vendor_name 'lexisnexis:ddp'

        required_attributes :threatmetrix_session_id,
                            :state_id_number,
                            :first_name,
                            :last_name,
                            :dob,
                            :ssn,
                            :address1,
                            :city,
                            :state,
                            :zipcode,
                            :request_ip

        optional_attributes :address2, :phone, :email, :uuid_prefix

        stage :resolution

        proof do |applicant, result|
          proof_applicant(applicant, result)
        end

        def send_verification_request(applicant)
          VerificationRequest.new(config: config, applicant: applicant).send
        end

        def proof_applicant(applicant, result)
          response = send_verification_request(applicant)
          process_response(response, result)
        end

        private

        def process_response(response, result)
          result.response_body = response.response_body
          result.transaction_id = body['request_id']
          request_result = body['request_result']
          review_status = body['review_status']
          result.review_status = review_status
          result.add_error(:request_result, request_result) unless request_result == 'success'
          result.add_error(:review_status, review_status) unless review_status == 'pass'
        end
      end
    end
  end
end
