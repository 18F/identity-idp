# frozen_string_literal: true

module Events
  module Profile
    class Created < ProfileEvent
      data_attributes :user_id

      def apply(profile)
        profile.user_id = user_id

        profile
      end
    end
  end
end
