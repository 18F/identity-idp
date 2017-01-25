module Idv
  class Attempter
    def initialize(current_user)
      @current_user = current_user
    end

    def increment
      current_user.update!(
        idv_attempts: current_user.idv_attempts + 1,
        idv_attempted_at: Time.zone.now
      )
    end

    def reset
      current_user.update!(idv_attempts: 0)
    end

    def attempts
      current_user.idv_attempts
    end

    def exceeded?
      return false if window_expired?

      # too many attempts in the window
      attempts >= idv_max_attempts && !window_expired?
    end

    def window_expired?
      attempted_at = current_user.idv_attempted_at

      # never attempted
      return true unless attempted_at.present?

      # last attempted in the past outside the window
      attempted_at + idv_attempt_window < Time.zone.now
    end

    def reset_attempts?
      window_expired?
    end

    private

    attr_reader :current_user

    def idv_max_attempts
      (Figaro.env.idv_max_attempts || 3).to_i
    end

    def idv_attempt_window
      (Figaro.env.idv_attempt_window_in_hours || 24).to_i.hours
    end
  end
end
