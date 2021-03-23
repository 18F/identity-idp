module Throttler
  class Increment
    def self.call(user_id, throttle_type, analytics: nil)
      throttle = Throttler::FindOrCreate.call(user_id, throttle_type)
      return throttle if throttle.maxed?
      Update.call(
        throttle: throttle,
        attributes: { attempts: throttle.attempts + 1, attempted_at: Time.zone.now },
        analytics: analytics,
      )
      throttle
    end
  end
end
