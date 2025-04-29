module AttemptsApiTrackingHelper
  class FakeAttemptsTracker
    include AttemptsApi::TrackerEvents

    attr_reader :events

    def initialize
      @events = Hash.new
    end

    def track_event(event, attributes = {})
      events[event] ||= []
      events[event] << attributes
      nil
    end

    def parse_failure_reason(result)
      errors = result.to_h[:error_details]

      if errors.present?
        parsed_errors = errors.keys.index_with do |k|
          errors[k].keys
        end
      end

      parsed_errors || result.errors.presence
    end

    def track_mfa_submit_event(_attributes)
      # no-op
    end

    def browser_attributes
      {}
    end
  end
end
