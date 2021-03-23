module Throttler
  class IsThrottledElseIncrement
    def self.call(user_id, throttle_type, analytics: nil)
      throttle = FindOrCreate.call(user_id, throttle_type)
      return throttle if throttle.throttled?
      Update.call(
        throttle: throttle,
        attributes: { attempts: throttle.attempts + 1, attempted_at: Time.zone.now },
        analytics: analytics,
      )
      false
    end
  end
end
