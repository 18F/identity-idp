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
    end

    it 'calls analytics tracking event' do
      expect(@attempts_api_tracker).to receive(:idv_rate_limited).with(
        limiter_type: :phone_otp,
      )
      subject.handle_too_many_otp_sends

      expect(@analytics).to have_logged_event('Idv: Phone OTP sends rate limited')
    end
  end

  describe '#handle_too_many_otp_attempts' do
    before do
      stub_analytics
      stub_attempts_tracker
    end

    it 'calls analytics tracking event' do
      expect(@attempts_api_tracker).to receive(:idv_rate_limited).with(
        limiter_type: :phone_otp,
      )
      subject.handle_too_many_otp_attempts

      expect(@analytics).to have_logged_event('Idv: Phone OTP attempts rate limited')
    end
  end
end
