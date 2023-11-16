module IrsAttemptsApi
  class Tracker
    include TrackerEvents

    def track_event(event_type, metadata = {})
    end

    def parse_failure_reason(result)
      return result.to_h[:error_details]&.transform_values(&:keys) || result.errors.presence
    end
  end
end
