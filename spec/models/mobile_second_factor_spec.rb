require 'rails_helper'

include Features::ActiveJobHelper

describe MobileSecondFactor, sms: true do
  before do
    reset_job_queues
  end

  describe '.transmit' do
    it 'calls SmsSenderOtpJob' do
      user = build_stubbed(:user, :with_mobile, otp_secret_key: 'lzmh6ekrnc5i6aaq')
      MobileSecondFactor.transmit(user)

      expect(SmsSenderOtpJob).to have_been_enqueued.with(global_id(user))
    end
  end
end
