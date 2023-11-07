module Proofing
  module Aamva
    class VerificationClient
      attr_reader :config

      # @param [Aamva::Proofer::Config] config
      def initialize(config)
        @config = config
      end

      def send_verification_request(applicant:, session_id: nil)
        Request::VerificationRequest.new(
          applicant:,
          session_id:,
          auth_token:,
          config:,
        ).send
      end

      private

      def auth_token
        @auth_token ||= AuthenticationClient.auth_token(config)
      end
    end
  end
end
