Ahoy.mount = false
Ahoy.throttle = false
Ahoy.api_only = true

module Ahoy
  class Store < Ahoy::Stores::ActiveRecordTokenStore
  end

  module Stores
    class ActiveRecordTokenStore < BaseStore
      def track_event(name, properties, _options)
        AhoyEvent.create!(
          user_id: user_id_from_uuid(properties),
          name: name,
          properties: properties
        )
      end

      private

      def user_id_from_uuid(properties)
        user = User.find_by_uuid(properties[:user_id]) || AnonymousUser.new
        user.id
      end
    end
  end
end
