module Throttler
  class IsThrottled
    def initialize(user_id, throttle_type)
      @user_id = user_id
      @throttle_type = throttle_type
    end

    def call(max_attempts, attempt_window_in_minutes)
      throttle = Throttler::FindOrCreate.new(user_id, throttle_type).call
      expired = window_expired?(throttle, attempt_window_in_minutes)
      return if expired

      # too many attempts in the window
      return unless throttle.attempts >= max_attempts && !expired
      throttle
    end

    private

    attr_accessor :user_id, :throttle_type

    def window_expired?(throttle, attempt_window_in_minutes)
      attempted_at = throttle.attempted_at

      # never attempted
      return true if attempted_at.blank?

      # last attempted in the past outside the window
      attempted_at + attempt_window_in_minutes.to_i.minutes < Time.zone.now
    end
  end
end
