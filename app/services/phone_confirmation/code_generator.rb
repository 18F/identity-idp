require 'otp_code_generator'

module PhoneConfirmation
  class CodeGenerator
    def self.call
      OtpCodeGenerator.generate_alphanumeric_digits(
        TwoFactorAuthenticatable::PROOFING_DIRECT_OTP_LENGTH,
      )
    end
  end
end
