require 'rails_helper'

describe Idv::OtpVerificationController do
  let(:user) { build(:user) }

  let(:phone) { '2255555000' }
  let(:user_phone_confirmation) { false }
  let(:phone_confirmation_otp_delivery_method) { 'sms' }
  let(:phone_confirmation_otp) { '777777' }
  let(:phone_confirmation_otp_sent_at) { Time.zone.now.to_s }

  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.applicant[:phone] = phone
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.phone_confirmation_otp_delivery_method =
      phone_confirmation_otp_delivery_method
    subject.idv_session.phone_confirmation_otp = phone_confirmation_otp
    subject.idv_session.phone_confirmation_otp_sent_at = phone_confirmation_otp_sent_at
  end

  describe '#show' do
    context 'the user has not been sent an otp' do
      let(:phone_confirmation_otp) { nil }
      let(:phone_confirmation_otp_sent_at) { nil }

      it 'redirects to the delivery method path' do
        get :show
        expect(response).to redirect_to(idv_otp_delivery_method_path)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        get :show
        expect(response).to redirect_to(idv_review_path)
      end
    end

    it 'tracks an analytics event' do
      get :show

      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_PHONE_CONFIRMATION_OTP_VISIT,
      )
    end
  end

  describe '#update' do
    context 'the user has not been sent an otp' do
      let(:phone_confirmation_otp) { nil }
      let(:phone_confirmation_otp_sent_at) { nil }

      it 'redirects to otp delivery method selection' do
        put :update, params: { code: phone_confirmation_otp }
        expect(response).to redirect_to(idv_otp_delivery_method_path)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        put :update, params: { code: phone_confirmation_otp }
        expect(response).to redirect_to(idv_review_path)
      end
    end

    it 'tracks an analytics event' do
      put :update, params: { code: phone_confirmation_otp }

      expected_result = {
        success: true,
        errors: {},
        code_expired: false,
        code_matches: true,
        second_factor_attempts_count: 0,
        second_factor_locked_at: nil,
      }

      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_PHONE_CONFIRMATION_OTP_SUBMITTED,
        expected_result,
      )
    end
  end
end
