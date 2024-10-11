# frozen_string_literal: true

module AccountCreation
  module DeviceProfiling
    class Proofer < Proofing::LexisNexis::Ddp::Proofer
      def proof(applicant)
        response = VerificationRequest.new(config: config, applicant: applicant).send_request
        build_result_from_response(response)
      rescue => exception
        NewRelic::Agent.notice_error(exception)
        Proofing::DdpResult.new(success: false, exception: exception)
      end
    end
  end
end
