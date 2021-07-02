require 'redacted_struct'

module Proofing
  module LexisNexis
    class Proofer < Proofing::Base
      Config = RedactedStruct.new(
        :instant_verify_workflow,
        :phone_finder_workflow,
        :account_id,
        :base_url,
        :username,
        :password,
        :request_mode,
        :request_timeout,
        keyword_init: true,
        allowed_members: [
          :instant_verify_workflow,
          :phone_finder_workflow,
          :base_url,
          :request_mode,
          :request_timeout,
        ],
      )

      attr_reader :config

      def initialize(**attrs)
        @config = Config.new(**attrs)
      end

      def proof_applicant(applicant, result)
        response = send_verification_request(applicant)
        result.transaction_id = response.conversation_id
        result.reference = response.reference
        return if response.verification_status == 'passed'

        response.verification_errors.each do |key, error_message|
          result.add_error(key, error_message)
        end
      end

      private

      def send_verification_request
        raise NotImplementedError, "#{__method__} should be defined by a subclass"
      end
    end
  end
end
