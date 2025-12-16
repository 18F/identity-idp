# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Proofers
        class InstantVerifyProofer < Proofer

          def initialize(attrs)
            super(attrs)
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
            result.account_lex_id = body['account_lex_id']
            result.session_id = body['session_id']

            result.success = !result.errors?
            result.client = 'lexisnexis'

            result
          end
        end
      end
    end
  end
end
