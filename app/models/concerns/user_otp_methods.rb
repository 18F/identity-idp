require 'otp_code_generator'

module UserOtpMethods
  extend ActiveSupport::Concern

  def max_login_attempts?
    second_factor_attempts_count.to_i >= IdentityConfig.store.login_otp_confirmation_max_attempts
  end

  def create_direct_otp
    otp = OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    set_redis_direct_otp(otp)

    update(
      direct_otp: otp,
      direct_otp_sent_at: Time.zone.now,
    )
    otp
  end

  def redis_direct_otp
    return nil if @redis_direct_otp == :undefined
    return @redis_direct_otp if defined?(@redis_direct_otp)
    @redis_direct_otp = REDIS_POOL.with do |client|
      client.get(
        "user:direct_otp:#{self.id}",
      )
    end
  end

  def redis_direct_otp_sent_at
    expires_at = redis_direct_otp_expires_at
    return unless expires_at

    expires_at - TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES.minutes
  end

  def redis_direct_otp_expires_at
    return nil if @redis_direct_otp_expires_at == :undefined
    return @redis_direct_otp_expires_at if defined?(@redis_direct_otp_expires_at)
    time = @redis_direct_otp_expires_at = REDIS_POOL.with do |client|
      client.expiretime(
        "user:direct_otp:#{self.id}",
      )
    end

    @redis_direct_otp_expires_at = Time.zone.at(time) if time

    @redis_direct_otp_expires_at
  end

  def set_redis_direct_otp(otp)
    expires_at = Time.zone.now + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES.minutes
    REDIS_POOL.with do |client|
      client.set(
        "user:direct_otp:#{self.id}",
        otp,
        exat: expires_at.to_i,
      )
    end

    @redis_direct_otp = otp
    @redis_direct_otp_epxires_at = expires_at

    otp
  end

  def clear_redis_direct_otp
    REDIS_POOL.with do |client|
      client.del(
        "user:direct_otp:#{self.id}",
      )
    end
    @redis_direct_otp = :undefined
    @redis_direct_otp_expires_at = :undefined
  end

  def generate_totp_secret
    ROTP::Base32.random(20) # 160-bit secret, per RFC 4226
  end

  def clear_direct_otp
    update(direct_otp: nil, direct_otp_sent_at: nil)
    clear_redis_direct_otp
  end
end
