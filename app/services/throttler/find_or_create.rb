module Throttler
  class FindOrCreate
    def initialize(user_id, throttle_type)
      @user_id = user_id
      @throttle_type = throttle_type
    end

    def call
      Throttle.find_or_create_by(user_id: user_id, throttle_type: throttle_type)
    end

    private

    attr_accessor :user_id, :throttle_type
  end
end
