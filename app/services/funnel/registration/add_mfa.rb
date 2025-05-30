# frozen_string_literal: true

module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method, analytics, threatmetrix_attrs)
        now = Time.zone.now
        funnel = RegistrationLog.create_or_find_by(user_id: user_id)
        return if funnel.registered_at.present?

        analytics.user_registration_user_fully_registered(mfa_method: mfa_method)
        process_threatmetrix_for_user(
          threatmetrix_attrs,
        )
        funnel.update!(registered_at: now)
      end

      def self.process_threatmetrix_for_user(threatmetrix_attrs)
        return unless FeatureManagement.account_creation_device_profiling_collecting_enabled?
        AccountCreationThreatMetrixJob.perform_now(**threatmetrix_attrs)
      end
    end
  end
end
