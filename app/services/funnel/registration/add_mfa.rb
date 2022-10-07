module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method, analytics)
        now = Time.zone.now
        funnel = RegistrationLog.find_or_create_by(user_id: user_id)
        return if funnel.registered_at.present?

        analytics.user_registration_user_fully_registered(mfa_method: mfa_method)
        funnel.update!(submitted_at: now, registered_at: now)
      end
    end
  end
end
