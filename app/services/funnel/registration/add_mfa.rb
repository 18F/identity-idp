# frozen_string_literal: true

module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method, analytics, threatmetrix_attrs)
        now = Time.zone.now
        funnel = RegistrationLog.create_or_find_by(user_id: user_id)
        return if funnel.registered_at.present?

        analytics.user_registration_user_fully_registered(mfa_method: mfa_method)
        device_profiling_result = process_threatmetrix_for_user(
          threatmetrix_attrs,
        )
        if device_profiling_result
          analytics.account_creation_tmx_result(**device_profiling_result.to_h)
        end
        funnel.update!(registered_at: now)
      end

      def self.process_threatmetrix_for_user(
        _threatmetrix_attrs
      )
        if IdentityConfig.store.ruby_workers_idv_enabled
          AuthenticationThreatMetrixJob.perform_later(**job_arguments)
        else
          AuthenticationThreatMetrixJob.perform_now(**job_arguments)
        end
      end
    end
  end
end
