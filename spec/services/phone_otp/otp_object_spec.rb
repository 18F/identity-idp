require 'rails_helper'

describe PhoneOtp::OtpObject do
  describe '.generate_for_delivery_method' do
    it 'generates an OTP object for voice' do
      result = described_class.generate_for_delivery_method('voice')

      expect(result.code).to match(/\d{6}/)
      expect(result.sent_at).to be_within(1.second).of(Time.zone.now)
      expect(result.delivery_method).to eq(:voice)
      expect(result.sms?).to eq(false)
      expect(result.voice?).to eq(true)
    end

    it 'generates an OTP object for sms' do
      result = described_class.generate_for_delivery_method('sms')

      expect(result.code).to match(/\d{6}/)
      expect(result.sent_at).to be_within(1.second).of(Time.zone.now)
      expect(result.delivery_method).to eq(:sms)
      expect(result.sms?).to eq(true)
      expect(result.voice?).to eq(false)
    end
  end

  describe '#matches_code?' do
    subject do
      described_class.new(
        code: '123456',
        sent_at: Time.zone.now,
        delivery_method: :sms,
      )
    end

    it 'returns true if the code matches' do
      expect(subject.matches_code?('123456')).to eq(true)
    end

    it 'returns false if the code does not match' do
      expect(subject.matches_code?('111111')).to eq(false)
    end

    it 'uses a secure comparison' do
      expect(Devise).to receive(:secure_compare).and_call_original

      subject.matches_code?('123456')
    end
  end

  describe '#expired?' do
    it 'returns false if the OTP is not expired' do
      otp_object = described_class.generate_for_delivery_method(:sms)

      expect(otp_object.expired?).to eq(false)

      Timecop.travel 9.minutes.from_now do
        expect(otp_object.expired?).to eq(false)
      end
    end

    it 'returns true if the OTP is expired' do
      otp_object = described_class.generate_for_delivery_method(:sms)

      Timecop.travel 11.minutes.from_now do
        expect(otp_object.expired?).to eq(true)
      end
    end
  end
end
