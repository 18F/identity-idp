require 'rails_helper'

RSpec.describe Idv::PhoneOtpRateLimitable, type: :controller do
  controller ApplicationController do
    include Idv::PhoneOtpRateLimitable

    def handle_max_attempts(_arg = nil)
      true
    end
  end

  describe '#handle_too_many_otp_sends' do
    before do
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
      allow(@irs_attempts_api_tracker).to receive(:track_event)
    end

    it 'calls analytics tracking event' do
      subject.handle_too_many_otp_sends

      expect(@analytics).to have_received(:track_event).with(
        'Idv: Phone OTP sends rate limited',
      )
    end

    it 'calls irs tracking event idv_phone_otp_sent_rate_limited' do
      subject.handle_too_many_otp_sends

      expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
        :idv_phone_otp_sent_rate_limited,
      )
    end
  end
end
