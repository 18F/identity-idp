module Idv
  class PhoneConfirmationOtpGenerator
    def self.generate_otp
      digits = Devise.direct_otp_length
      SecureRandom.random_number(10**digits).to_s.rjust(digits, '0')
    end
  end
end
