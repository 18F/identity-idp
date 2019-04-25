module Throttler
  class IsThrottled
    def self.call(user_id, throttle_type)
      throttle = FindOrCreate.call(user_id, throttle_type)
      expired = throttle.expired?
      return if expired

      return unless throttle.maxed? && !expired
      throttle
    end
  end
end
