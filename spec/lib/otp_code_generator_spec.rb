require 'rails_helper'

RSpec.describe OtpCodeGenerator do
  describe '.generate_digits' do
    subject(:generate_digits) do
      OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end

    it 'pads short strings with zeroes' do
      expect(SecureRandom).to receive(:random_number).and_return(0)

      expect(generate_digits).to eq('0' * TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end
  end

  describe '.generate_alphanumeric_digits' do
    subject(:generate_alphanumeric_digits) do
      OtpCodeGenerator.generate_alphanumeric_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end

    it 'generates crockford-32 encoded words' do
      expect(generate_alphanumeric_digits).
        to match(/\A[a-z0-9]{#{TwoFactorAuthenticatable::DIRECT_OTP_LENGTH}}\Z/io)
    end

    it 'filters out profanity' do
      expect(SecureRandom).to receive(:random_number).
        and_return(
          Base32::Crockford.decode('FART1'),
          Base32::Crockford.decode('FART2'),
          Base32::Crockford.decode('ABCDE'),
        )

      expect(generate_alphanumeric_digits).to eq('0ABCDE')
    end

    it 'pads short strings with zeroes' do
      expect(SecureRandom).to receive(:random_number).and_return(0)

      expect(generate_alphanumeric_digits).to eq('0' * TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end
  end
end
