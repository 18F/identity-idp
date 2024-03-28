module PushNotification
  class LocalEventQueue
    class << self
      # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
      def events
        @events ||= []
      end

      def clear!
        @events = []
      end
      # rubocop:enable ThreadSafety/InstanceVariableInClassMethod
    end
  end
end
