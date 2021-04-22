require 'rails_helper'

RSpec.describe PhoneConfirmation::ConfirmationSession do
  describe '.start' do
    it 'starts a session for voice' do
      result = described_class.start(
        delivery_method: 'voice',
        phone: '+1 (202) 123-4567',
      )

      expect(result.code).to match(/[a-z0-9]{6}/i)
      expect(result.phone).to eq('+1 (202) 123-4567')
      expect(result.sent_at).to be_within(1.second).of(Time.zone.now)
      expect(result.delivery_method).to eq(:voice)
      expect(result.sms?).to eq(false)
      expect(result.voice?).to eq(true)
    end

    it 'starts a session for sms' do
      result = described_class.start(
        delivery_method: 'sms',
        phone: '+1 (202) 123-4567',
      )

      expect(result.code).to match(/[a-z0-9]{6}/i)
      expect(result.phone).to eq('+1 (202) 123-4567')
      expect(result.sent_at).to be_within(1.second).of(Time.zone.now)
      expect(result.delivery_method).to eq(:sms)
      expect(result.sms?).to eq(true)
      expect(result.voice?).to eq(false)
    end
  end

  describe '#regenerate_otp' do
    it 'returns a copy with a new OTP and expiration' do
      original_session = described_class.start(
        delivery_method: 'sms',
        phone: '+1 (202) 123-4567',
      )

      new_session = original_session.regenerate_otp

      expect(original_session.code).to_not eq(new_session.code)
      expect(original_session.sent_at).to_not eq(new_session.sent_at)
      expect(original_session.phone).to eq(new_session.phone)
      expect(original_session.delivery_method).to eq(new_session.delivery_method)
    end
  end

  describe '#matches_code?' do
    subject do
      described_class.new(
        code: '123456',
        phone: '+1 (202) 123-4567',
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
      otp_object = described_class.start(phone: '+1 (225) 123-4567', delivery_method: :sms)

      expect(otp_object.expired?).to eq(false)

      Timecop.travel 9.minutes.from_now do
        expect(otp_object.expired?).to eq(false)
      end
    end

    it 'returns true if the OTP is expired' do
      otp_object = described_class.start(phone: '+1 (225) 123-4567', delivery_method: :sms)

      Timecop.travel 11.minutes.from_now do
        expect(otp_object.expired?).to eq(true)
      end
    end
  end
end
