module Db
  module Profile
    class HasLivenessCheck
      def self.call(user_id)
        components = ::Profile.where(user_id: user_id, active: true).first&.proofing_components
        return unless components
        JSON.parse(components)['liveness_check']
      end
    end
  end
end
