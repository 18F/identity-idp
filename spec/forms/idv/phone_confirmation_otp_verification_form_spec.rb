require 'rails_helper'

describe Idv::PhoneConfirmationOtpVerificationForm do
  let(:user) { create(:user, :signed_up) }
  let(:idv_session) { double(Idv::Session) }
  let(:phone_confirmation_otp) { '123456' }
  let(:phone_confirmation_otp_sent_at) { Time.zone.now.to_s }

  before do
    allow(idv_session).to receive(:phone_confirmation_otp).
      and_return(phone_confirmation_otp)
    allow(idv_session).to receive(:phone_confirmation_otp_sent_at).
      and_return(phone_confirmation_otp_sent_at)
  end

  describe '#submit' do
    def try_submit(code)
      described_class.new(
        user: user, idv_session: idv_session,
      ).submit(code: code)
    end

    context 'when the code matches' do
      it 'returns a successful result' do
        expect(idv_session).to receive(:user_phone_confirmation=).with(true)

        result = try_submit(phone_confirmation_otp)

        expect(result.success?).to eq(true)
      end

      it 'clears the second factor attempts' do
        expect(idv_session).to receive(:user_phone_confirmation=).with(true)

        user.update(second_factor_attempts_count: 4)

        try_submit(phone_confirmation_otp)

        expect(user.reload.second_factor_attempts_count).to eq(0)
      end
    end

    context 'when the code does not match' do
      it 'returns an unsuccessful result' do
        expect(idv_session).to_not receive(:user_phone_confirmation=)

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
      let(:phone_confirmation_otp_sent_at) { 11.minutes.ago.to_s }

      it 'returns an unsuccessful result' do
        expect(idv_session).to_not receive(:user_phone_confirmation=)

        result = try_submit(phone_confirmation_otp)

        expect(result.success?).to eq(false)
      end

      it 'increment second factor attempts and locks out user after too many' do
        2.times do
          try_submit(phone_confirmation_otp)
        end

        user.reload

        expect(user.second_factor_attempts_count).to eq(2)
        expect(user.second_factor_locked_at).to eq(nil)

        try_submit(phone_confirmation_otp)

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
