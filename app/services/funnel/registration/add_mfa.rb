module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method, analytics)
        funnel = RegistrationLog.create_or_find_by(user_id: user.id)
        return if funnel.registered_at.present?

        analytics.user_registration_user_fully_registered(mfa_method: mfa_method)
        funnel.update!(registered_at: now)
      end
    end
  end
end
