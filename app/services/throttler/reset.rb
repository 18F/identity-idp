module Throttler
  class Reset
    def self.call(user_id, throttle_type)
      throttle = Throttle.find_or_create_by(user_id: user_id, throttle_type: throttle_type)
      throttle.update(attempts: 0)
      throttle
    end
  end
end
