require 'rails_helper'

describe UserOtpSender do
  describe '#send_otp' do
    context 'when user does not have unconfirmed_mobile' do
      it 'sends OTP to mobile' do
        user = build_stubbed(:user, direct_otp: '1234')

        expect(SmsSenderOtpJob).to receive(:perform_later).with('1234', user.mobile)

        UserOtpSender.new(user).send_otp
      end
    end

    context 'when user has an unconfirmed_mobile' do
      it 'generates a new OTP and only sends OTP to unconfirmed_mobile' do
        user = build(
          :user, unconfirmed_mobile: '5005550006', direct_otp: '1234'
        )

        allow(SmsSenderOtpJob).to receive(:perform_later)

        UserOtpSender.new(user).send_otp

        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(user.direct_otp, user.unconfirmed_mobile)

        expect(user.direct_otp).to_not eq '1234'
      end
    end
  end

  describe '#reset_otp_state' do
    context 'when the user has a confirmed mobile and unconfirmed_mobile' do
      it 'sets unconfirmed_mobile to nil' do
        user = create(:user, :with_mobile, unconfirmed_mobile: '5005550006')

        UserOtpSender.new(user).reset_otp_state

        expect(user.unconfirmed_mobile).to be_nil
      end
    end
  end
end
