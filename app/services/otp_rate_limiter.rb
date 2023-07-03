class OtpRateLimiter
  def initialize(phone:, user:, phone_confirmed:)
    @phone = phone
    @user = user
    @phone_confirmed = phone_confirmed
  end

  def exceeded_otp_send_limit?
    if rate_limit_period_expired?
      reset_count_and_otp_last_sent_at
      return false
    end

    max_requests_reached?
  end

  def max_requests_reached?
    rate_limiter.limited?
  end

  def rate_limit_period_expired?
    rate_limiter.expired?
  end

  def reset_count_and_otp_last_sent_at
    rate_limiter.reset!
  end

  def lock_out_user
    UpdateUser.new(user: user, attributes: { second_factor_locked_at: Time.zone.now }).call
  end

  def increment
    rate_limiter.increment!
  end

  def otp_last_sent_at
    rate_limiter.attempted_at
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(rate_limit_type: :phone_otp, target: rate_limit_key)
  end

  private

  attr_reader :phone, :user, :phone_confirmed

  def otp_findtime
    IdentityConfig.store.otp_delivery_blocklist_findtime.minutes
  end

  def otp_maxretry_times
    IdentityConfig.store.otp_delivery_blocklist_maxretry
  end

  def phone_fingerprint
    @phone_fingerprint ||= Pii::Fingerprinter.fingerprint(PhoneFormatter.format(phone))
  end

  def rate_limit_key
    "#{phone_fingerprint}:#{phone_confirmed}"
  end
end
