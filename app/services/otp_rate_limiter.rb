class OtpRateLimiter
  def initialize(phone:, user:)
    @phone = phone
    @user = user
  end

  def exceeded_otp_send_limit?
    return false if entry_for_current_phone.blank?

    if rate_limit_period_expired?
      reset_count_and_otp_last_sent_at
      return false
    end

    max_requests_reached?
  end

  def max_requests_reached?
    entry_for_current_phone.otp_send_count >= otp_maxretry_times
  end

  def rate_limit_period_expired?
    otp_last_sent_at.present? && (otp_last_sent_at + otp_findtime) < Time.zone.now
  end

  def reset_count_and_otp_last_sent_at
    entry_for_current_phone.update(otp_last_sent_at: Time.zone.now, otp_send_count: 0)
  end

  def lock_out_user
    UpdateUser.new(user: user, attributes: { second_factor_locked_at: Time.zone.now }).call
  end

  def increment
    entry_for_current_phone.otp_send_count += 1
    entry_for_current_phone.otp_last_sent_at = Time.zone.now
    entry_for_current_phone.save!
  end

  private

  attr_reader :phone, :user

  def entry_for_current_phone
    @entry ||= OtpRequestsTracker.find_or_create_with_phone(phone)
  end

  def otp_last_sent_at
    entry_for_current_phone.otp_last_sent_at
  end

  def otp_findtime
    Figaro.env.otp_delivery_blocklist_findtime.to_i.minutes
  end

  def otp_maxretry_times
    Figaro.env.otp_delivery_blocklist_maxretry.to_i
  end
end
