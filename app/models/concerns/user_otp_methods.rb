require 'otp_code_generator'

module UserOtpMethods
  extend ActiveSupport::Concern

  def max_login_attempts?
    second_factor_attempts_count.to_i >= max_login_attempts
  end

  def create_direct_otp
    otp = OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)

    update(
      direct_otp: otp,
      direct_otp_sent_at: Time.zone.now,
    )
  end

  def generate_totp_secret
    ROTP::Base32.random(20) # 160-bit secret, per RFC 4226
  end

  def authenticate_direct_otp(code)
    return false if direct_otp.nil?
    return false if direct_otp_expired?
    return false if direct_otp != Base32::Crockford.normalize(code)
    clear_direct_otp
    true
  end

  def direct_otp_expired?
    Time.zone.now > direct_otp_sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
  end

  private

  def clear_direct_otp
    update(direct_otp: nil, direct_otp_sent_at: nil)
  end

  def max_login_attempts
    3
  end
end
