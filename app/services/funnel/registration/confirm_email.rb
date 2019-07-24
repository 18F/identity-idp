module Funnel
  module Registration
    class ConfirmEmail
      # rubocop:disable Rails/SkipsModelValidations
      def self.call(user_id)
        RegistrationLog.where(user_id: user_id).update_all(confirmed_at: Time.zone.now)
      end
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
