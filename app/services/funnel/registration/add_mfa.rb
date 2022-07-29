module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method, analytics)
        now = Time.zone.now
        funnel = RegistrationLog.find_by(user_id: user_id)
        return if funnel.blank? || funnel.second_mfa.present?

        if funnel.first_mfa.present?
          params = {
            second_mfa: mfa_method,
          }
        else
          params = {
            first_mfa: mfa_method,
            first_mfa_at: now,
            registered_at: now,
          }
          analytics.user_registration_user_fully_registered(mfa_method: mfa_method)
        end

        funnel.update!(params)
      end
    end
  end
end
