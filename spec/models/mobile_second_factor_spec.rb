require 'rails_helper'

include Features::ActiveJobHelper

describe MobileSecondFactor do
  describe '.transmit' do
    it 'calls SmsSenderOtpJob' do
      user = build_stubbed(:user, :with_mobile, otp_secret_key: 'lzmh6ekrnc5i6aaq')

      expect(SmsSenderOtpJob).to receive(:perform_later).with(user)

      MobileSecondFactor.transmit(user)
    end
  end
end
