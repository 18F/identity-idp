# frozen_string_literal: true

module Events
  module Profile
    class Activated < Events::Profile::BaseEvent
      data_attributes :user_id

      def apply(profile)
        profile.active = true
        profile.activated_at = self.created_at

        profile
      end
    end
  end
end
