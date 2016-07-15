require 'rails_helper'

describe UserOtpSender do
  describe '#send_otp' do
    it 'sends OTP via SMS' do
      user = build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq')

      expect(SmsSenderOtpJob).to receive(:perform_later).with(user.direct_otp, user.mobile)

      UserOtpSender.new(user).send_otp
    end
  end
end
