module IrsAttemptsApiTrackingHelper
  class FakeAttemptsTracker

    include IrsAttemptsApi::TrackerEvents

    attr_reader :events

    def initialize
      @events = Hash.new
    end

    def track_event(event, attributes = {})
      events[event] ||= []
      events[event] << attributes
      nil
    end

    def track_mfa_submit_event(_attributes)
      # no-op
    end

    def browser_attributes
      {}
    end
  end
end