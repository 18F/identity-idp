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
    return throttle.throttled? if IdentityConfig.store.redis_throttle_otp_rate_limiter_read_enabled

    entry_for_current_phone.otp_send_count > otp_maxretry_times
  end

  def rate_limit_period_expired?
    return throttle.expired? if IdentityConfig.store.redis_throttle_otp_rate_limiter_read_enabled
    otp_last_sent_at.present? && (otp_last_sent_at + otp_findtime) < Time.zone.now
  end

  def reset_count_and_otp_last_sent_at
    entry_for_current_phone.update(otp_last_sent_at: Time.zone.now, otp_send_count: 0)

    throttle.reset!
  end

  def lock_out_user
    UpdateUser.new(user: user, attributes: { second_factor_locked_at: Time.zone.now }).call
  end

  def increment
    # DO NOT MEMOIZE
    @entry = OtpRequestsTracker.atomic_increment(entry_for_current_phone.id)
    throttle.increment!
    nil
  end

  def otp_last_sent_at
    if IdentityConfig.store.redis_throttle_otp_rate_limiter_read_enabled
      throttle.attempted_at
    else
      entry_for_current_phone.otp_last_sent_at
    end
  end

  private

  attr_reader :phone, :user, :phone_confirmed

  # rubocop:disable Naming/MemoizedInstanceVariableName
  def entry_for_current_phone
    @entry ||= OtpRequestsTracker.find_or_create_with_phone_and_confirmed(phone, phone_confirmed)
  end
  # rubocop:enable Naming/MemoizedInstanceVariableName

  def otp_findtime
    IdentityConfig.store.otp_delivery_blocklist_findtime.minutes
  end

  def otp_maxretry_times
    IdentityConfig.store.otp_delivery_blocklist_maxretry
  end

  def phone_fingerprint
    @phone_fingerprint ||= Pii::Fingerprinter.fingerprint(PhoneFormatter.format(phone))
  end

  def throttle
    @throttle ||= Throttle.new(throttle_type: :phone_otp, target: throttle_key)
  end

  def throttle_key
    "#{phone_fingerprint}:#{phone_confirmed}"
  end
end
