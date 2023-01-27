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
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Proofing::DdpResult.new(exception: exception)
        end

        private

        def build_result_from_response(verification_response)
          result = Proofing::DdpResult.new
          body = verification_response.response_body

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
