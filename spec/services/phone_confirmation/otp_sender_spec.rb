require 'rails_helper'

describe PhoneConfirmation::OtpSender do
  let(:user) { create(:user, :signed_up) }
  let(:phone) { '+1 (225) 555-5000' }
  let(:otp) { '111111' }
  let(:delivery_method) { :sms }
  let(:phone_confirmation_session) do
    PhoneConfirmation::ConfirmationSession.new(
      code: otp,
      phone: phone,
      sent_at: Time.zone.now,
      delivery_method: delivery_method
    )
  end
  let(:context) { :confirmation }

  subject do
    described_class.new(
      user: user,
      phone_confirmation_session: phone_confirmation_session,
      context: context,
    )
  end

  context 'when the context is confirmation' do
    let(:context) { :confirmation }

    it 'sends confirmation OTPs' do
      expect(Telephony).to receive(:send_confirmation_otp).with(
        to: phone,
        otp: otp,
        expiration: 10,
        channel: delivery_method,
      )

      result = subject.send_otp

      expect(result.success?).to eq(true)
    end
  end

  context 'when the context is authentication' do
    let(:context) { :authentication }

    it 'sends authentication OTPs' do
      expect(Telephony).to receive(:send_authentication_otp).with(
        to: phone,
        otp: otp,
        expiration: 10,
        channel: delivery_method,
      )

      result = subject.send_otp

      expect(result.success?).to eq(true)
    end
  end

  context 'when too many OTPs have been sent to the phone' do
    it 'returns a failure result and does not send an OTP' do
      otp_requests_tracker = OtpRequestsTracker.find_or_create_with_phone(phone)
      2.times { OtpRequestsTracker.atomic_increment(otp_requests_tracker.id) }

      expect(UserDecorator.new(user.reload).locked_out?).to eq(false)

      result = subject.send_otp

      expect(UserDecorator.new(user.reload).locked_out?).to eq(true)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(base: ['To many OTP requests'])
      expect(subject.rate_limited?).to eq(true)
      expect(Telephony::Test::Message.messages.length).to eq(0)
    end
  end

  context 'when the telephony gem raises an error' do
    it 'returns a failure result' do
      telephony_error = Telephony::TelephonyError.new('error message')
      expect(Telephony).to receive(:send_confirmation_otp).and_raise(telephony_error)

      result = subject.send_otp

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(base: [telephony_error.friendly_message])
      expect(result.extra).to eq(
        telephony_error_class: 'Telephony::TelephonyError',
        telephony_error_message: 'error message',
      )
      expect(subject.telephony_error?).to eq(true)
      expect(subject.telephony_error).to eq(telephony_error)
    end
  end
end
