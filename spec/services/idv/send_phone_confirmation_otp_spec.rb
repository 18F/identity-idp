require 'rails_helper'

describe Idv::SendPhoneConfirmationOtp do
  let(:phone) { '2255555000' }
  let(:parsed_phone) { '+1 225-555-5000' }
  let(:otp_delivery_preference) { 'sms' }
  let(:phone_confirmation_otp) { '777777' }
  let(:idv_session) { Idv::Session.new(user_session: {}, current_user: user, issuer: '') }

  let(:user) { create(:user, :signed_up) }

  let(:exceeded_otp_send_limit) { false }
  let(:otp_rate_limiter) { OtpRateLimiter.new(user: user, phone: phone) }

  before do
    # Setup Idv::Session
    idv_session.applicant = { phone: phone }
    idv_session.phone_confirmation_otp_delivery_method = otp_delivery_preference

    # Mock Idv::GeneratePhoneConfirmationOtp
    allow(Idv::GeneratePhoneConfirmationOtp).to receive(:call).
      and_return(phone_confirmation_otp)

    # Mock OtpRateLimiter
    allow(OtpRateLimiter).to receive(:new).with(user: user, phone: parsed_phone).
      and_return(otp_rate_limiter)
    allow(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).
      and_return(exceeded_otp_send_limit)
  end

  subject { described_class.new(user: user, idv_session: idv_session) }

  describe '#call' do
    context 'with sms' do
      it 'sends an sms' do
        allow(Telephony).to receive(:send_confirmation_otp)

        result = subject.call

        expect(result.success?).to eq(true)

        sent_at = Time.zone.parse(idv_session.phone_confirmation_otp_sent_at)

        expect(idv_session.phone_confirmation_otp).to eq(phone_confirmation_otp)
        expect(sent_at).to be_within(1.second).of(Time.zone.now)
        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: phone_confirmation_otp,
          to: parsed_phone,
          expiration: 10,
          channel: :sms,
        )
      end
    end

    context 'with voice' do
      let(:otp_delivery_preference) { 'voice' }

      it 'makes a phone call' do
        allow(Telephony).to receive(:send_confirmation_otp)

        result = subject.call

        expect(result.success?).to eq(true)

        sent_at = Time.zone.parse(idv_session.phone_confirmation_otp_sent_at)

        expect(idv_session.phone_confirmation_otp).to eq(phone_confirmation_otp)
        expect(sent_at).to be_within(1.second).of(Time.zone.now)
        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: phone_confirmation_otp,
          to: parsed_phone,
          expiration: 10,
          channel: :voice,
        )
      end
    end

    context 'when the user has requested too many otps' do
      let(:exceeded_otp_send_limit) { true }

      it 'does not make a phone call or send an sms' do
        expect(Telephony).to_not receive(:send_authentication_otp)
        expect(Telephony).to_not receive(:send_confirmation_otp)

        result = subject.call

        expect(result.success?).to eq(false)
        expect(idv_session.phone_confirmation_otp).to be_nil
        expect(idv_session.phone_confirmation_otp_sent_at).to be_nil
      end
    end
  end

  describe '#user_locked_out?' do
    before do
      allow(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).
        and_return(exceeded_otp_send_limit)
    end

    context 'the user is locked out' do
      let(:exceeded_otp_send_limit) { true }

      it 'returns true' do
        subject.call

        expect(subject.user_locked_out?).to eq(true)
      end
    end

    context 'the user is not locked out' do
      it 'returns false' do
        subject.call

        expect(subject.user_locked_out?).to be_falsey
      end
    end
  end
end
