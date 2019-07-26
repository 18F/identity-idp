module Funnel
  module Registration
    class Create
      def self.call(user_id)
        user = User.find(user_id)
        return unless user
        RegistrationLog.create(user_id: user_id, submitted_at: user.created_at)
      end
    end
  end
end
