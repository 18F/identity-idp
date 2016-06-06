require 'rails_helper'

describe UserOtpSender do
  describe '#send_otp' do
    context 'when user does not have unconfirmed_mobile' do
      it 'sends OTP to mobile' do
        user = build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq')

        expect(SmsSenderOtpJob).to receive(:perform_later).with(user.otp_code, user.mobile)

        UserOtpSender.new(user).send_otp
      end
    end

    context 'when user has an unconfirmed_mobile' do
      it 'generates a new otp_secret_key and sends OTP to unconfirmed_mobile' do
        user = build_stubbed(
          :user, unconfirmed_mobile: '5005550006', otp_secret_key: 'lzmh6ekrnc5i6aaq'
        )

        allow(SmsSenderOtpJob).to receive(:perform_later)

        UserOtpSender.new(user).send_otp

        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(user.otp_code, user.unconfirmed_mobile)

        expect(user.otp_secret_key).to_not eq 'lzmh6ekrnc5i6aaq'
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
