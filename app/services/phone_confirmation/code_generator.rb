require 'otp_code_generator'

module PhoneConfirmation
  class CodeGenerator
    def self.call
      digits = TwoFactorAuthenticatable.direct_otp_length
      OtpCodeGenerator.generate_digits(digits)
    end
  end
end
