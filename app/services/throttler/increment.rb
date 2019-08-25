module Throttler
  class Increment
    def self.call(user_id, throttle_type)
      throttle = Throttler::FindOrCreate.call(user_id, throttle_type)
      return throttle if throttle.maxed?
      throttle.update(attempts: throttle.attempts + 1, attempted_at: Time.zone.now)
      throttle
    end
  end
end
