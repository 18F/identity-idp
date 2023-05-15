module Proofing
  module Aamva
    class VerificationClient
      attr_reader :config

      # @param [Aamva::Proofer::Config] config
      def initialize(config)
        @config = config
      end

      def send_verification_request(applicant:, session_id: nil)
        get_verification_request(applicant, session_id).send
      end

      # @param [Pii::Attributes] applicant
      # @param [String|nil] session_id
      # @return [Request::VerificationRequest]
      def get_verification_request(applicant, session_id)
        Request::VerificationRequest.new(
          applicant: applicant,
          session_id: session_id,
          auth_token: auth_token,
          config: config,
        )
      end

      private

      def auth_token
        @auth_token ||= AuthenticationClient.auth_token(config)
      end
    end
  end
end
