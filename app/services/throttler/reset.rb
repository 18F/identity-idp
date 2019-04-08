module Throttler
  class Reset
    def initialize(user_id, throttle_type)
      @user_id = user_id
      @throttle_type = throttle_type
    end

    def call
      throttler = FindOrCreate.new(user_id, throttle_type).call
      throttler.update(attempts: 0)
    end

    private

    attr_accessor :user_id, :throttle_type
  end
end
