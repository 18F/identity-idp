module Throttler
  class Increment
    def self.call(user_id, throttle_type)
      throttler = Throttler::FindOrCreate.call(user_id, throttle_type)
      throttler.update(attempts: throttler.attempts + 1, attempted_at: Time.zone.now)
    end
  end
end
