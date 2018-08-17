require 'rails_helper'

require 'rails_helper'

describe Idv::OtpVerificationController do
  let(:user) { build(:user) }

  let(:phone) { '5555555000' }
  let(:user_phone_confirmation) { false }
  let(:phone_confirmation_otp_delivery_method) { 'sms' }
  let(:phone_confirmation_otp) { nil }
  let(:phone_confirmation_otp_sent_at) { nil }

  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.params[:phone] = '2255555000'
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.phone_confirmation_otp_delivery_method =
      phone_confirmation_otp_delivery_method
    subject.idv_session.phone_confirmation_otp = phone_confirmation_otp
    subject.idv_session.phone_confirmation_otp_sent_at = phone_confirmation_otp_sent_at
  end

  describe '#new' do
    context 'the user has not selected a delivery method' do
      let(:phone_confirmation_otp_delivery_method) { nil }

      it 'redirects to otp deleivery method selection' do
        get :new
        expect(response).to redirect_to(idv_otp_delivery_method_path)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        get :new
        expect(response).to redirect_to(idv_review_path)
      end
    end

    it 'tracks an analytics event' do
      get :new

      expected_result = {
        success: true,
        errors: {},
        otp_delivery_preference: :sms,
        country_code: '1',
        area_code: '225',
        rate_limit_exceeded: false,
      }

      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_PHONE_CONFIRMATION_OTP_SENT,
        expected_result
      )
    end
  end

  describe '#show' do
    let(:phone_confirmation_otp) { '777777' }
    let(:phone_confirmation_otp_sent_at) { Time.zone.now.to_s }

    context 'the user has not selected a delivery method' do
      let(:phone_confirmation_otp_delivery_method) { nil }

      it 'redirects to otp deleivery method selection' do
        get :show
        expect(response).to redirect_to(idv_otp_delivery_method_path)
      end
    end

    context 'the user has not been sent an otp' do
      let(:phone_confirmation_otp) { nil }
      let(:phone_confirmation_otp_sent_at) { nil }

      it 'redirects to the otp send path' do
        get :show
        expect(response).to redirect_to(idv_send_phone_otp_path)
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
        Analytics::IDV_PHONE_CONFIRMATION_OTP_VISIT
      )
    end
  end

  describe '#update' do
    let(:phone_confirmation_otp) { '777777' }
    let(:phone_confirmation_otp_sent_at) { Time.zone.now.to_s }

    context 'the user has not selected a delivery method' do
      let(:phone_confirmation_otp_delivery_method) { nil }

      it 'redirects to otp deleivery method selection' do
        put :update, params: { code: phone_confirmation_otp }
        expect(response).to redirect_to(idv_otp_delivery_method_path)
      end
    end

    context 'the user has not been sent an otp' do
      let(:phone_confirmation_otp) { nil }
      let(:phone_confirmation_otp_sent_at) { nil }

      it 'redirects to the otp send path' do
        put :update, params: { code: phone_confirmation_otp }
        expect(response).to redirect_to(idv_send_phone_otp_path)
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
        expected_result
      )
    end
  end
end
