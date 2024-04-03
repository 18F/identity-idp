# frozen_string_literal: true

module PushNotification
  class LocalEventQueue
    class << self
      def events
        @events ||= []
      end

      def clear!
        @events = []
      end
    end
  end
end
