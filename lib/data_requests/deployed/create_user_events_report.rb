# frozen_string_literal: true

module DataRequests
  module Deployed
    class CreateUserEventsReport
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def call
        user.events.order(created_at: :asc).map do |event|
          {
            event_name: event.event_type,
            date_time: event.created_at,
            ip: event.ip,
            disavowed_at: event.disavowed_at,
            user_agent: event.device&.user_agent,
            device_cookie: event.device&.cookie_uuid,
          }
        end
      end
    end
  end
end
