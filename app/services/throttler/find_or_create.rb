module Throttler
  class FindOrCreate
    def self.call(user_id, throttle_type)
      throttle = Throttle.find_or_create_by(user_id: user_id, throttle_type: throttle_type)
      reset_if_expired_and_maxed(throttle)
    end

    def self.reset_if_expired_and_maxed(throttle)
      return throttle unless throttle.expired? && throttle.maxed?
      throttle.update(attempts: 0, throttled_count: throttle.throttled_count.to_i + 1)
      throttle
    end
    private_class_method :reset_if_expired_and_maxed
  end
end
