# frozen_string_literal: true

module IrsAttemptsApi
  class Tracker
    include TrackerEvents

    def track_event(event_type, metadata = {})
    end

    def parse_failure_reason(result)
      return result.to_h[:error_details] || result.errors.presence
    end
  end
end
