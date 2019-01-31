module Idv
  class Attempter
    def self.idv_max_attempts
      (Figaro.env.idv_max_attempts || 3).to_i
    end

    def initialize(current_user)
      @current_user = current_user
    end

    def increment
      UpdateUser.new(
        user: current_user,
        attributes: {
          idv_attempts: current_user.idv_attempts + 1,
          idv_attempted_at: Time.zone.now,
        },
      ).call
    end

    def reset
      UpdateUser.new(
        user: current_user,
        attributes: { idv_attempts: 0 },
      ).call
    end

    def attempts
      current_user.idv_attempts
    end

    def exceeded?
      return false if window_expired?

      # too many attempts in the window
      attempts >= self.class.idv_max_attempts && !window_expired?
    end

    def window_expired?
      attempted_at = current_user.idv_attempted_at

      # never attempted
      return true if attempted_at.blank?

      # last attempted in the past outside the window
      attempted_at + idv_attempt_window < Time.zone.now
    end

    def reset_attempts?
      window_expired?
    end

    private

    attr_reader :current_user

    def idv_attempt_window
      (Figaro.env.idv_attempt_window_in_hours || 24).to_i.hours
    end
  end
end
