module Throttler
  class IsThrottledElseIncrement
    def self.call(user_id, throttle_type)
      throttle = FindOrCreate.call(user_id, throttle_type)
      return throttle if throttle.throttled?
      throttle.update(attempts: throttle.attempts + 1, attempted_at: Time.zone.now)
      false
    end
  end
end
