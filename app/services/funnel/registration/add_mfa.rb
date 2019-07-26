module Funnel
  module Registration
    class AddMfa
      def self.call(user_id, mfa_method)
        funnel = RegistrationLog.find_by(user_id: user_id)
        return unless funnel
        if funnel.first_mfa.blank?
          first_mfa(funnel, mfa_method)
        elsif funnel.second_mfa.blank?
          second_mfa(funnel, mfa_method)
        end
      end

      def self.first_mfa(funnel, mfa_method)
        funnel.first_mfa = mfa_method
        now = Time.zone.now
        funnel.first_mfa_at = now
        funnel.registered_at = now if mfa_method == 'backup_codes'
        funnel.save
      end
      private_class_method :first_mfa

      def self.second_mfa(funnel, mfa_method)
        funnel.second_mfa = mfa_method
        funnel.registered_at = Time.zone.now if funnel.registered_at.nil?
        funnel.save
      end
      private_class_method :second_mfa
    end
  end
end
