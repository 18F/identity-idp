require 'rails_helper'

RSpec.describe OtpCodeGenerator do
  describe '.generate_digits' do
    before do
      allow(IdentityConfig.store).to receive(:otp_use_alphanumeric).and_return(otp_use_alphanumeric)
    end
    let(:otp_use_alphanumeric) { true }

    subject(:generate_digits) do
      OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end

    it 'generates crockford-32 encoded words' do
      expect(generate_digits).
        to match(/\A[a-z0-9]{#{TwoFactorAuthenticatable::DIRECT_OTP_LENGTH}}\Z/i)
    end

    it 'filters out profanity' do
      expect(SecureRandom).to receive(:random_number).
        and_return(
          Base32::Crockford.decode('FART1'),
          Base32::Crockford.decode('FART2'),
          Base32::Crockford.decode('ABCDE'),
        )

      expect(generate_digits).to eq('0ABCDE')
    end

    it 'pads short strings with zeroes' do
      expect(SecureRandom).to receive(:random_number).and_return(0)

      expect(generate_digits).to eq('0' * TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end

    context 'wehn otp_use_alphanumeric is disabled' do
      let(:otp_use_alphanumeric) { false }


      it 'is a digits-only code' do
        int_value = Base32::Crockford.decode('ABC')

        expect(SecureRandom).to receive(:random_number).
          and_return(int_value)

        expect(generate_digits).to eq("0#{int_value}")
      end
    end
  end
end