require 'rails_helper'

describe Idv::SendPhoneConfirmationOtp do
  let(:phone) { '+1 225-555-5000' }
  let(:parsed_phone) { Phonelib.parse(phone) }
  let(:delivery_preference) { :sms }
  let(:otp_code) { '777777' }
  let(:user_phone_confirmation_session) do
    PhoneConfirmation::ConfirmationSession.new(
      code: '123456',
      phone: phone,
      sent_at: Time.zone.now,
      delivery_method: delivery_preference,
    )
  end
  let(:idv_session) do
    Idv::Session.new(user_session: {}, current_user: user, service_provider: nil)
  end

  let(:user) { create(:user, :signed_up) }

  let(:exceeded_otp_send_limit) { false }
  let(:otp_rate_limiter) { OtpRateLimiter.new(user: user, phone: phone, phone_confirmed: true) }

  before do
    # Setup Idv::Session
    idv_session.user_phone_confirmation_session = user_phone_confirmation_session

    # Mock PhoneConfirmation::CodeGenerator
    allow(PhoneConfirmation::CodeGenerator).to receive(:call).
      and_return(otp_code)

    # Mock OtpRateLimiter
    allow(OtpRateLimiter).to receive(:new).with(user: user, phone: phone, phone_confirmed: true).
      and_return(otp_rate_limiter)
    allow(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).
      and_return(exceeded_otp_send_limit)
  end

  subject { described_class.new(user: user, idv_session: idv_session) }

  describe '#call' do
    let(:now) { Time.zone.now }

    context 'with sms' do
      it 'sends an sms' do
        allow(Telephony).to receive(:send_confirmation_otp).and_call_original

        result = travel_to(now) { subject.call }

        expect(result.success?).to eq(true)

        phone_confirmation_session = idv_session.user_phone_confirmation_session

        expect(phone_confirmation_session.code).to eq(otp_code)
        expect(phone_confirmation_session.sent_at.to_i).to eq(now.to_i)
        expect(phone_confirmation_session.delivery_method).to eq(:sms)

        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: otp_code,
          to: phone,
          expiration: 10,
          channel: :sms,
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
          extra_metadata: {
            area_code: parsed_phone.area_code,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            resend: nil,
          },
        )
      end
    end

    context 'with voice' do
      let(:delivery_preference) { :voice }

      it 'makes a phone call' do
        allow(Telephony).to receive(:send_confirmation_otp).and_call_original

        result = travel_to(now) { subject.call }

        expect(result.success?).to eq(true)

        phone_confirmation_session = idv_session.user_phone_confirmation_session

        expect(phone_confirmation_session.code).to eq(otp_code)
        expect(phone_confirmation_session.sent_at.to_i).to eq(now.to_i)
        expect(phone_confirmation_session.delivery_method).to eq(:voice)

        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: otp_code,
          to: phone,
          expiration: 10,
          channel: :voice,
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
          extra_metadata: {
            area_code: parsed_phone.area_code,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            resend: nil,
          },
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
