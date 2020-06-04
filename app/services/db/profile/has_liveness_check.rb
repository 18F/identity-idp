module Db
  module Profile
    class HasLivenessCheck
      def self.call(user_id)
        User.find_by(user_id: user_id)&.active_profile&.has_liveness_check?
      end
    end
  end
end
