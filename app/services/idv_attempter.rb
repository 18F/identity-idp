class IdvAttempter
  def initialize(current_user)
    @current_user = current_user
  end

  def exceeded?
    return false if window_expired?

    # too many attempts in the window
    idv_attempts >= idv_max_attempts && !window_expired?
  end

  def window_expired?
    # never attempted
    attempted_at = current_user.idv_attempted_at
    return true unless attempted_at.present?

    # last attempted in the past outside the window
    attempted_at + idv_attempt_window < Time.zone.now
  end

  def reset_attempts?
    idv_attempts >= idv_max_attempts && window_expired?
  end

  private

  attr_reader :current_user

  def idv_attempts
    current_user.idv_attempts
  end

  def idv_max_attempts
    (Figaro.env.idv_max_attempts || 3).to_i
  end

  def idv_attempt_window
    (Figaro.env.idv_attempt_window_in_hours || 24).to_i.hours
  end
end
