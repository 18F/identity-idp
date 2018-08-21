require 'rails_helper'

describe Idv::ResendOtpController do
  let(:user) { build(:user) }

  let(:phone) { '2255555000' }
  let(:user_phone_confirmation) { false }
  let(:phone_confirmation_otp_delivery_method) { 'sms' }

  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.params[:phone] = phone
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.phone_confirmation_otp_delivery_method =
      phone_confirmation_otp_delivery_method
  end

  describe '#create' do
    context 'the user has not selected a delivery method' do
      let(:phone_confirmation_otp_delivery_method) { nil }

      it 'redirects to otp deleivery method selection' do
        post :create
        expect(response).to redirect_to(idv_otp_delivery_method_path)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        post :create
        expect(response).to redirect_to(idv_review_path)
      end
    end

    it 'tracks an analytics event' do
      post :create

      expected_result = {
        success: true,
        errors: {},
        otp_delivery_preference: :sms,
        country_code: '1',
        area_code: '225',
        rate_limit_exceeded: false,
      }

      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_PHONE_CONFIRMATION_OTP_RESENT,
        expected_result
      )
    end
  end
end
