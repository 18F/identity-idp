module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method)
        now = Time.zone.now
        funnel = RegistrationLog.find_by(user_id: user_id)
        return if funnel.blank? || funnel.second_mfa.present?

        params = if funnel.first_mfa.present?
                   {
                     second_mfa: mfa_method,
                   }
                 else
                   {
                     first_mfa: mfa_method,
                     first_mfa_at: now,
                     registered_at: now,
                   }
                 end

        funnel.update!(params)
      end
    end
  end
end
