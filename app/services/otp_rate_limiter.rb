class OtpRateLimiter
  def initialize(current_user)
    @current_user = current_user
  end

  def exceeded_otp_send_limit?
    otp_last_sent_at = current_user.otp_last_sent_at
    now = Time.zone.now

    otp_last_sent_at.present? &&
      otp_last_sent_at + otp_findtime > now &&
      current_user.otp_send_count >= otp_maxretry_times
  end

  def lock_out_user
    UpdateUser.new(
      user: current_user,
      attributes: {
        second_factor_locked_at: Time.zone.now,
        otp_last_sent_at: nil,
        otp_send_count: 0,
      }
    ).call
  end

  def increment
    current_user.otp_last_sent_at = Time.zone.now
    current_user.otp_send_count += 1
  end

  private

  attr_reader :current_user

  def otp_findtime
    Figaro.env.otp_delivery_blocklist_findtime.to_i.minutes
  end

  def otp_maxretry_times
    Figaro.env.otp_delivery_blocklist_maxretry.to_i
  end
end
