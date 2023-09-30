# frozen_string_literal: true

module Events
  module Profile
    class Created < ProfileEvent
      data_attributes :user_id

      def apply(profile)
        profile.user_id = user_id

        profile
      end

      def build_aggregate
        build_profile(user_id: data['user_id'])
      end
    end
  end
end
