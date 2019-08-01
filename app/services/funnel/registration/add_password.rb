module Funnel
  module Registration
    class AddPassword
      # rubocop:disable Rails/SkipsModelValidations
      def self.call(user_id)
        RegistrationLog.where(user_id: user_id).update_all(password_at: Time.zone.now)
      end
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
