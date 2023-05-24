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
      allow(@analytics).to receive(:track_event)
    end

    it 'calls analytics tracking event' do
      subject.handle_too_many_otp_sends

      expect(@analytics).to have_received(:track_event).with(
        'Idv: Phone OTP sends rate limited',
        proofing_components: nil,
      )
    end
  end
end
