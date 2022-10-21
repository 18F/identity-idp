require 'securerandom'

class OtpCodeGenerator
  def self.generate_digits(digits)
    SecureRandom.random_number(10 ** digits).to_s.rjust(digits, '0')
  end

  def self.generate_alphanumeric_digits(digits)
    ProfanityDetector.without_profanity do
      # 5 bits per character means we must multiply what we want by 5
      # :length adds zero padding in case it's a smaller number
      random_bytes = SecureRandom.random_number(2 ** (digits * 5))
      Base32::Crockford.encode(random_bytes, length: digits)
    end
  end
end
