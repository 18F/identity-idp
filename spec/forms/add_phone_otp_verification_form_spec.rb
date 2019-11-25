require 'rails_helper'

describe AddPhoneOtpVerificationForm do
  let(:user) { create(:user, :signed_up) }
  let(:phone) { '+1 (225) 555-5000' }
  let(:otp_sent_at) { Time.zone.now }
  let(:otp_code) { '123456' }
  let(:phone_confirmation_session) do
    PhoneConfirmation::ConfirmationSession.new(
      code: otp_code,
      phone: phone,
      sent_at: otp_sent_at,
      delivery_method: :sms,
    )
  end

  describe '#submit' do
    def try_submit(code)
      described_class.new(
        user: user, phone_confirmation_session: phone_confirmation_session,
      ).submit(code: code)
    end

    context 'when the code matches' do
      it 'returns a successful result' do
        result = try_submit(otp_code)

        expect(result.success?).to eq(true)
      end

      it 'clears the second factor attempts' do
        user.update(second_factor_attempts_count: 4)

        try_submit(otp_code)

        expect(user.reload.second_factor_attempts_count).to eq(0)
      end
    end

    context 'when the code does not match' do
      it 'returns an unsuccessful result' do
        result = try_submit('xxxxxx')

        expect(result.success?).to eq(false)
      end

      it 'increments second factor attempts' do
        2.times do
          try_submit('xxxxxx')
        end

        user.reload

        expect(user.second_factor_attempts_count).to eq(2)
        expect(user.second_factor_locked_at).to eq(nil)

        try_submit('xxxxxx')

        expect(user.second_factor_attempts_count).to eq(3)
        expect(user.second_factor_locked_at).to be_within(1.second).of(Time.zone.now)
      end
    end

    context 'when the code is expired' do
      let(:otp_sent_at) { 11.minutes.ago }

      it 'returns an unsuccessful result' do
        result = try_submit(otp_code)

        expect(result.success?).to eq(false)
      end

      it 'increment second factor attempts and locks out user after too many' do
        2.times do
          try_submit(otp_code)
        end

        user.reload

        expect(user.second_factor_attempts_count).to eq(2)
        expect(user.second_factor_locked_at).to eq(nil)

        try_submit(otp_code)

        expect(user.second_factor_attempts_count).to eq(3)
        expect(user.second_factor_locked_at).to be_within(1.second).of(Time.zone.now)
      end
    end

    it 'handles nil and empty codes' do
      result = try_submit(nil)

      expect(result.success?).to eq(false)

      result = try_submit('')

      expect(result.success?).to eq(false)
    end
  end
end
