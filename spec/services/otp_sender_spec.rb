require 'rails_helper'

describe UserOtpSender do
  describe '#send_otp' do
    context 'when user is two_factor_enabled and does not have unconfirmed_mobile' do
      it 'sends OTP to mobile' do
        user = build_stubbed(:user)

        allow(user).to receive(:two_factor_enabled?).and_return(true)

        expect(SmsSenderOtpJob).to receive(:perform_later).with(user)

        UserOtpSender.new(user).send_otp
      end
    end

    context 'when user is two_factor_enabled and has an unconfirmed_mobile' do
      it 'generates a new OTP and only sends OTP to unconfirmed_mobile' do
        user = build_stubbed(
          :user, unconfirmed_mobile: '5005550006', otp_secret_key: 'lzmh6ekrnc5i6aaq')

        allow(user).to receive(:two_factor_enabled?).and_return(true)

        expect(SmsSenderOtpJob).to receive(:perform_later).with(user)

        UserOtpSender.new(user).send_otp

        expect(user.otp_secret_key).to_not eq 'lzmh6ekrnc5i6aaq'
      end
    end
  end

  describe '#reset_otp_state' do
    context 'when the user has a confirmed mobile and unconfirmed_mobile' do
      it 'sets unconfirmed_mobile to nil and keeps mobile 2FA' do
        user = create(:user, :with_mobile, unconfirmed_mobile: '5005550006')

        UserOtpSender.new(user).reset_otp_state

        expect(user.unconfirmed_mobile).to be_nil
      end
    end
  end
end
