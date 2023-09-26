# frozen_string_literal: true

module Events
  module Profile
    class Created < Events::Profile::BaseEvent
      data_attributes :user_id, :metadata

      def apply(profile)
        profile.user_id = user_id
        profile.metadata = metadata

        profile
      end
    end
  end
end
