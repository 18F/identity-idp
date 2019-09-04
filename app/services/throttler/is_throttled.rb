module Throttler
  class IsThrottled
    def self.call(user_id, throttle_type)
      throttle = FindOrCreate.call(user_id, throttle_type)
      throttle.throttled? ? throttle : nil
    end
  end
end
