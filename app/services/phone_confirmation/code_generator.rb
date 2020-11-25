require 'otp_code_generator'

module PhoneConfirmation
  class CodeGenerator
    def self.call
      OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end
  end
end
