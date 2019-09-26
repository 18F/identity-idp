module Throttler
  class RemainingCount
    def self.call(user_id, throttle_type)
      throttle = FindOrCreate.call(user_id, throttle_type)
      throttle.remaining_count
    end
  end
end
