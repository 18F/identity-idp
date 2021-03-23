module Throttler
  class Update
    def self.call(throttle:, attributes:, analytics: nil)
      was_throttled = throttle.throttled?
      throttle.update(attributes)
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: throttle.throttle_type,
      ) if analytics.present? && !was_throttled && throttle.throttled?
      throttle
    end
  end
end
