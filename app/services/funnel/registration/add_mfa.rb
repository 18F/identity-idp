module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method)
        now = Time.zone.now
        funnel = RegistrationLog.find_by(user_id: user_id)
        return if funnel.blank? || funnel.first_mfa.present?
        funnel.update!(
          first_mfa: mfa_method,
          first_mfa_at: now,
          registered_at: now,
        )
      end
    end
  end
end
