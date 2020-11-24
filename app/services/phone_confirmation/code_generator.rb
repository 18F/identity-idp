module PhoneConfirmation
  class CodeGenerator
    def self.call
      digits = TwoFactorAuthenticatable.direct_otp_length
      SecureRandom.random_number(10**digits).to_s.rjust(digits, '0')
    end
  end
end
