# frozen_string_literal: true

module AccountCreation
  module DeviceProfile
    class VerificationRequest < Proofing::LexisNexis::Ddp::VerificationRequest
      private

      def build_request_body
        {
          api_key: config.api_key,
          org_id: config.org_id,
          account_email: applicant[:email],
          event_type: 'ACCOUNT_CREATION',
          policy: IdentityConfig.store.authentication_tmx_policy, # Need a sep policy from proofing
          service_type: 'all',
          session_id: applicant[:threatmetrix_session_id],
          input_ip_address: applicant[:request_ip],
          custom_attribute:,
        }.to_json
      end
    end
  end
end
