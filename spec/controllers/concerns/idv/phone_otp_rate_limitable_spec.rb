require 'rails_helper'

RSpec.describe Idv::PhoneOtpRateLimitable, type: :controller do
  let(:user) { create(:user, :fully_registered) }
  let(:idv_session) do
    Idv::Session.new(user_session: {}, current_user: user, service_provider: nil)
  end
  let(:phone_number) { '123-456-7890' }

  controller ApplicationController do
    include Idv::PhoneOtpRateLimitable

    def handle_max_attempts(_arg = nil)
      true
    end

    def user_session
      {}
    end
  end
  before do
    allow(Idv::Session).to receive(:new).and_return(idv_session)
    allow(idv_session).to receive_message_chain(:user_phone_confirmation_session, :phone)
      .and_return(phone_number)
  end

  describe '#handle_too_many_otp_sends' do
    before do
      stub_analytics
      stub_attempts_tracker
    end

    it 'calls analytics tracking event' do
      expect(@attempts_api_tracker).to receive(:idv_rate_limited).with(
        limiter_type: :phone_otp,
        phone_number: Phonelib.parse(phone_number).e164,
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
        phone_number: Phonelib.parse(phone_number).e164,
      )
      subject.handle_too_many_otp_attempts

      expect(@analytics).to have_logged_event('Idv: Phone OTP attempts rate limited')
    end
  end
end
