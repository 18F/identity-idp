require 'rails_helper'

RSpec.describe Idv::PhoneConfirmationSession do
  let(:user) { build(:user) }
  let(:six_char_alphanumeric) { /[a-z0-9]{6}/i }
  let(:ten_digit_numeric) { /[0-9]{10}/i }

  describe '.start' do
    it 'starts a session for voice' do
      result = described_class.start(
        delivery_method: 'voice',
        phone: '+1 (202) 123-4567',
        user: user,
      )

      expect(result.code).to match(six_char_alphanumeric)
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
        user: user,
      )

      expect(result.code).to match(six_char_alphanumeric)
      expect(result.phone).to eq('+1 (202) 123-4567')
      expect(result.sent_at).to be_within(1.second).of(Time.zone.now)
      expect(result.delivery_method).to eq(:sms)
      expect(result.sms?).to eq(true)
      expect(result.voice?).to eq(false)
    end
  end

  describe '.generate_code' do
    let(:ab_test_enabled) { false }
    before do
      allow(IdentityConfig.store).to receive(:ab_testing_idv_ten_digit_otp_enabled).
        and_return(ab_test_enabled)
    end

    context 'A/B test not enabled' do
      it 'generates a six-character alphanumeric code' do
        code = described_class.generate_code(user: user)

        expect(code).to match(six_char_alphanumeric)
      end
    end
    context '10-digit A/B test enabled' do
      let(:ab_test_enabled) { true }

      context '10-digit A/B test puts user in :six_alphanumeric_otp bucket' do
        before do
          stub_const(
            'AbTests::IDV_TEN_DIGIT_OTP',
            FakeAbTestBucket.new.tap { |ab| ab.assign(user.uuid => :six_alphanumeric_otp) },
          )
        end

        it 'generates a six-character alphanumeric code' do
          code = described_class.generate_code(user: user)

          expect(code).to match(six_char_alphanumeric)
        end
      end

      context '10-digit A/B test puts user in :ten_digit_otp bucket' do
        before do
          stub_const(
            'AbTests::IDV_TEN_DIGIT_OTP',
            FakeAbTestBucket.new.tap { |ab| ab.assign(user.uuid => :ten_digit_otp) },
          )
        end

        it 'generates a ten-digit numeric code' do
          code = described_class.generate_code(user: user)

          expect(code).to match(ten_digit_numeric)
        end
      end
    end
  end

  describe '#regenerate_otp' do
    it 'returns a copy with a new OTP and expiration' do
      original_session = described_class.start(
        delivery_method: 'sms',
        phone: '+1 (202) 123-4567',
        user: user,
      )

      new_session = original_session.regenerate_otp

      expect(original_session.code).to_not eq(new_session.code)
      expect(original_session.sent_at).to_not eq(new_session.sent_at)
      expect(original_session.phone).to eq(new_session.phone)
      expect(original_session.delivery_method).to eq(new_session.delivery_method)
    end
  end

  describe '#matches_code?' do
    let(:code) do
      OtpCodeGenerator.generate_alphanumeric_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    end
    subject do
      described_class.new(
        code: code,
        phone: '+1 (202) 123-4567',
        sent_at: Time.zone.now,
        delivery_method: :sms,
        user: user,
      )
    end

    it 'returns true if the code matches' do
      expect(subject.matches_code?(code)).to eq(true)
    end

    it 'returns true if the code matches with different case' do
      random_case_code = code.chars.map { |c| (rand 2) == 0 ? c.downcase : c.upcase }.join
      lowercase_code = code.downcase
      uppercase_code = code.upcase

      expect(subject.matches_code?(random_case_code)).to eq(true)
      expect(subject.matches_code?(lowercase_code)).to eq(true)
      expect(subject.matches_code?(uppercase_code)).to eq(true)
    end

    it 'returns true if the code is prefixed with a # sign' do
      prefixed_code = "##{code}"

      expect(subject.matches_code?(prefixed_code)).to eq(true)
    end

    it 'returns false if the code does not match' do
      bad_code = '1' * (TwoFactorAuthenticatable::DIRECT_OTP_LENGTH - 1)
      expect(subject.matches_code?(bad_code)).to eq(false)
    end

    it 'uses a secure comparison' do
      expect(Devise).to receive(:secure_compare).and_call_original

      subject.matches_code?('123456')
    end
  end

  describe '#expired?' do
    it 'returns false if the OTP is not expired' do
      otp_object = described_class.start(
        phone: '+1 (225) 123-4567',
        delivery_method: :sms,
        user: user,
      )

      expect(otp_object.expired?).to eq(false)

      travel_to 9.minutes.from_now do
        expect(otp_object.expired?).to eq(false)
      end
    end

    it 'returns true if the OTP is expired' do
      otp_object = described_class.start(
        phone: '+1 (225) 123-4567',
        delivery_method: :sms,
        user: user,
      )

      travel_to 11.minutes.from_now do
        expect(otp_object.expired?).to eq(true)
      end
    end
  end
end
