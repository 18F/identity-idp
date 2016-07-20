require 'rails_helper'

describe UserOtpSender do
  describe '#send_otp' do
    it 'sends OTP via SMS' do
      user = build_stubbed(:user)

      expect(SmsSenderOtpJob).to receive(:perform_later).with('123', user.mobile)

      UserOtpSender.new(user).send_otp('123')
    end
  end
end
