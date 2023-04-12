require 'otp_code_generator'

module UserOtpMethods
  extend ActiveSupport::Concern

  def max_login_attempts?
    second_factor_attempts_count.to_i >= IdentityConfig.store.login_otp_confirmation_max_attempts
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

  def clear_direct_otp
    update(direct_otp: nil, direct_otp_sent_at: nil)
  end
end
