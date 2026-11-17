# frozen_string_literal: true

require 'otp_code_generator'

module UserOtpMethods
  extend ActiveSupport::Concern

  def max_login_attempts?
    second_factor_attempts_count.to_i >= IdentityConfig.store.login_otp_confirmation_max_attempts
  end

  # Issues a one-time code and records which phone it is delivered to, as a keyed fingerprint
  # rather than the number itself. Verification accepts the code only for that phone, so a code
  # delivered to one number cannot confirm or authenticate a different one.
  #
  # @param phone [String] the number the code is sent to
  def create_direct_otp(phone)
    otp = OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)

    update(
      direct_otp: otp,
      direct_otp_sent_at: Time.zone.now,
      direct_otp_phone_fingerprint: self.class.direct_otp_phone_fingerprint(phone),
    )
  end

  # True when the pending one-time code was delivered to this phone.
  def direct_otp_sent_to?(phone)
    direct_otp_phone_fingerprint.present? &&
      Pii::Fingerprinter.verify(PhoneFormatter.format(phone).to_s, direct_otp_phone_fingerprint)
  end

  def generate_totp_secret
    ROTP::Base32.random(20) # 160-bit secret, per RFC 4226
  end

  def clear_direct_otp
    update(direct_otp: nil, direct_otp_sent_at: nil, direct_otp_phone_fingerprint: nil)
  end

  class_methods do
    def direct_otp_phone_fingerprint(phone)
      Pii::Fingerprinter.fingerprint(PhoneFormatter.format(phone).to_s)
    end
  end
end
