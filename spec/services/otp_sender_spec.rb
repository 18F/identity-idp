require 'rails_helper'

describe UserOtpSender do
  let(:user) { build_stubbed(:user) }

  describe '#send_otp' do
    context 'with no delivery method' do
      it 'sends OTP via SMS by default' do
        expect(SmsSenderOtpJob).to receive(:perform_later).with('123', user.phone)

        UserOtpSender.new(user).send_otp('123')
      end
    end

    context 'with voice delivery method' do
      let(:options) { { otp_method: :voice } }

      it 'sends OTP via voice delivery' do
        expect(VoiceSenderOtpJob).to receive(:perform_later).with('123', user.phone)

        UserOtpSender.new(user).send_otp('123', options)
      end
    end

    context 'with SMS delivery method' do
      let(:options) { { otp_method: :sms } }

      it 'sends OTP via voice delivery' do
        expect(SmsSenderOtpJob).to receive(:perform_later).with('123', user.phone)

        UserOtpSender.new(user).send_otp('123', options)
      end
    end
  end
end
