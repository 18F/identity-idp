# require 'ostruct'
# require 'redacted_struct'

module Proofing
  module Aamva
    class Proofer
      Config = RedactedStruct.new(
        :auth_request_timeout,
        :auth_url,
        :cert_enabled,
        :private_key,
        :public_key,
        :verification_request_timeout,
        :verification_url,
        keyword_init: true,
        allowed_members: [
          :auth_request_timeout,
          :auth_url,
          :cert_enabled,
          :verification_request_timeout,
          :verification_url,
        ],
      )

      attr_reader :config

      # Instance methods
      def initialize(config)
        @config = Config.new(config)
      end

      def proof(applicant)
        aamva_applicant = Aamva::Applicant.from_proofer_applicant(OpenStruct.new(applicant))
        response = Aamva::VerificationClient.new(
          config,
        ).send_verification_request(
          applicant: aamva_applicant,
        )
        Aamva::Result.new(response)
      rescue => exception
        NewRelic::Agent.notice_error(exception)
        Proofing::Result.new(exception: exception)
      end
    end
  end
end
