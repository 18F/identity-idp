module Throttler
  class IsThrottledElseIncrement
    def self.call(user_id, throttle_type)
      return true if Throttler::IsThrottled.call(user_id, throttle_type)
      Throttler::Increment.call(user_id, throttle_type)
      false
    end
  end
end
