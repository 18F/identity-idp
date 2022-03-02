require 'securerandom'

class OtpCodeGenerator
  def self.generate_digits(digits)
    SecureRandom.random_number(10**digits).to_s.rjust(digits, '0')
  end
end
