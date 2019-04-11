module Throttler
  class FindOrCreate
    def self.call(user_id, throttle_type)
      throttle = Throttle.find_or_create_by(user_id: user_id, throttle_type: throttle_type)
      reset_if_expired(throttle)
    end

    def self.reset_if_expired(throttle)
      return throttle unless throttle.expired? && throttle.attempts.zero?
      throttle.update(attempts: 0)
      throttle
    end
    private_class_method :reset_if_expired
  end
end
