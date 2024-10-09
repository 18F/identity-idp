# frozen_string_literal: true
module AccountCreation
  module DeviceProfiling
    class VerificationRequest < Proofing::LexisNexis::Ddp::VerificationRequest
      private

      def build_request_body
        {
          api_key: config.api_key,
          org_id: config.org_id,
          account_email: applicant[:email],
          account_telephone: applicant[:phone] || '',
          event_type: 'DEVICE_REGISTRATION', #Temp event type until we find one we like
          policy: IdentityConfig.store.lexisnexis_threatmetrix_policy,
          service_type: 'all',
          session_id: applicant[:threatmetrix_session_id],
          input_ip_address: applicant[:request_ip],
        }.to_json
      end
    end
  end
end
  