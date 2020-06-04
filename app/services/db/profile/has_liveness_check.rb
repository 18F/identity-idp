module Db
  module Profile
    class HasLivenessCheck
      def self.call(user_id)
        User.find_by(id: user_id)&.active_profile&.includes_liveness_check?
      end
    end
  end
end
