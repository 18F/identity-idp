module IrsAttemptsApi
  class Tracker
    include TrackerEvents

    def track_event(event_type, metadata = {})
    end
  end
end
