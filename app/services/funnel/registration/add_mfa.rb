# frozen_string_literal: true

module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method, analytics, threatmetrix_attrs = {})
        now = Time.zone.now
        funnel = RegistrationLog.create_or_find_by(user_id: user_id)
        return if funnel.registered_at.present?

        analytics.user_registration_user_fully_registered(mfa_method: mfa_method)
        @device_profiling_result = process_threatmetrix_for_user(
          threatmetrix_attrs
        )
        if @device_profiling_result
          analytics.account_creation_tmx_result(**@device_profiling_result.to_h)
        end
        funnel.update!(registered_at: now)
      end

      private 

      def self.process_threatmetrix_for_user(
        threatmetrix_attrs
      )
        return unless FeatureManagement.account_creation_device_profiling_collecting_enabled?
        return unless threatmetrix_attrs[:in_account_creation_flow] && 
          threatmetrix_attrs[:threatmetrix_session_id]
        AccountCreation::DeviceProfiling.new.proof(
          request_ip: threatmetrix_attrs[:request_ip],
          threatmetrix_session_id: threatmetrix_attrs[:threatmetrix_session_id],
          user_email: threatmetrix_attrs[:email],
        )
      end
    end
  end
end
