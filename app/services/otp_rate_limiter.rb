class OtpRateLimiter
  def initialize(phone:, user:, phone_confirmed:)
    @phone = phone
    @user = user
    @phone_confirmed = phone_confirmed
  end

  def exceeded_otp_send_limit?
    puts "def exceeded_otp_send_limit?"

    if rate_limit_period_expired?
      reset_count_and_otp_last_sent_at
      puts "  rate limit period expired; exceeded_otp_send_limit?: returning false"
      return false
    end

    rv = max_requests_reached?
    puts "  exceeded_otp_send_limit?: returning #{rv.inspect}"
    rv
  end

  def max_requests_reached?
    puts "def max_requests_reached?"

    rv = rate_limiter.limited?
    puts "  max_requests_reached?: returning #{rv.inspect}"
    rv
  end

  def rate_limit_period_expired?
    puts "def rate_limit_period_expired?"

    rv = rate_limiter.expired?
    puts "  rate_limit_period_expired?: returning #{rv.inspect}"
    rv
  end

  def reset_count_and_otp_last_sent_at
    puts "def reset_count_and_otp_last_sent_at"

    rv = rate_limiter.reset!
    puts "  reset_count_and_otp_last_sent_at: returning #{rv.inspect}"
    rv
  end

  def lock_out_user
    puts "def lock_out_user"

    rv = UpdateUser.new(user: user, attributes: { second_factor_locked_at: Time.zone.now }).call
    puts "  lock_out_user: returning #{rv.inspect}"
    rv
  end

  def increment
    puts "def increment"

    rv = rate_limiter.increment!
    puts "  increment: returning #{rv.inspect}"
    rv
  end

  def otp_last_sent_at
    puts "def otp_last_sent_at"

    rv = rate_limiter.attempted_at
    puts "  otp_last_sent_at: returning: #{rv.inspect}"
    rv
  end

  def rate_limiter
    puts "def rate_limiter"

    rv = (@rate_limiter ||= RateLimiter.new(rate_limit_type: :phone_otp, target: rate_limit_key))
    puts "  rate_limiter: returning #{rv.inspect}"
    rv
  end

  private

  attr_reader :phone, :user, :phone_confirmed

  def otp_findtime
    puts "def otp_findtime"

    rv = IdentityConfig.store.otp_delivery_blocklist_findtime.minutes
    puts "  otp_findtime: returning #{rv.inspect}"
    rv
  end

  def otp_maxretry_times
    puts "def otp_maxretry_times"

    rv = IdentityConfig.store.otp_delivery_blocklist_maxretry
    puts "  otp_maxretry_times: returning #{rv.inspect}"
    rv
  end

  def phone_fingerprint
    puts "def phone_fingerprint"

    rv = @phone_fingerprint ||= Pii::Fingerprinter.fingerprint(PhoneFormatter.format(phone))
    puts "  phone_fingerprint: returning #{rv.inspect}"
    rv
  end

  def rate_limit_key
    puts "def rate_limit_key"

    rv = "#{phone_fingerprint}:#{phone_confirmed}"
    puts "  rate_limit_key: returning #{rv.inspect}"
    rv
  end
end
