require 'otp_code_generator'

module UserOtpMethods
  extend ActiveSupport::Concern

  def max_login_attempts?
    second_factor_attempts_count.to_i >= max_login_attempts
  end

  def create_direct_otp
    update(
      direct_otp: OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable.direct_otp_length),
      direct_otp_sent_at: Time.zone.now,
    )
  end

  def generate_totp_secret
    ROTP::Base32.random_base32
  end

  def authenticate_direct_otp(code)
    return false if direct_otp.nil? || direct_otp != code || direct_otp_expired?
    clear_direct_otp
    true
  end

  def direct_otp_expired?
    Time.zone.now > direct_otp_sent_at + TwoFactorAuthenticatable.direct_otp_valid_for_seconds
  end

  private

  def clear_direct_otp
    update(direct_otp: nil, direct_otp_sent_at: nil)
  end

  def max_login_attempts
    3
  end
end
