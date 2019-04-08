module Throttler
  class Increment
    def initialize(user_id, throttle_type)
      @user_id = user_id
      @throttle_type = throttle_type
    end

    def call
      throttler = Throttler::FindOrCreate.new(user_id, throttle_type).call
      throttler.update(attempts: throttler.attempts + 1, attempted_at: Time.zone.now)
    end

    private

    attr_accessor :user_id, :throttle_type
  end
end
