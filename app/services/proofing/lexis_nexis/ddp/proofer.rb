module Proofing
  module LexisNexis
    module Ddp
      class Proofer
        VALID_REVIEW_STATUSES = %w[pass review reject]

        attr_reader :config

        def initialize(attrs)
          @config = Config.new(attrs)
        end

        def proof(applicant)
          response = VerificationRequest.new(config:, applicant:).send_request
          build_result_from_response(response)
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          Proofing::DdpResult.new(success: false, exception:)
        end

        private

        def build_result_from_response(verification_response)
          result = Proofing::DdpResult.new
          body = verification_response.response_body

          result.response_body = body
          result.transaction_id = body['request_id']
          request_result = body['request_result']
          review_status = body['review_status']

          validate_review_status!(review_status)

          result.review_status = review_status
          result.add_error(:request_result, request_result) unless request_result == 'success'
          result.add_error(:review_status, review_status) unless review_status == 'pass'

          result.success = !result.errors?
          result.client = 'lexisnexis'

          result
        end

        def validate_review_status!(review_status)
          return if VALID_REVIEW_STATUSES.include?(review_status)

          raise "Unexpected ThreatMetrix review_status value: #{review_status}"
        end
      end
    end
  end
end
