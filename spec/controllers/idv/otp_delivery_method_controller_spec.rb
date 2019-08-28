require 'rails_helper'

describe Idv::OtpDeliveryMethodController do
  let(:user) { build(:user) }

  before do
    stub_verify_steps_one_and_two(user)
    subject.idv_session.address_verification_mechanism = 'phone'
    subject.idv_session.applicant[:phone] = '2255555000'
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = false
  end

  describe '#new' do
    context 'user has not selected phone verification method' do
      before do
        subject.idv_session.address_verification_mechanism = 'usps'
      end

      it 'redirects to the review controller' do
        get :new
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user has confirmed phone number' do
      before do
        subject.idv_session.user_phone_confirmation = true
      end

      it 'redirects to the review controller' do
        get :new
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user has not completed phone step' do
      before do
        subject.idv_session.vendor_phone_confirmation = false
      end

      it 'redirects to the phone controller' do
        get :new
        expect(response).to redirect_to idv_phone_path
      end
    end

    context 'user has selected phone verification and not confirmed phone' do
      it 'renders' do
        get :new
        expect(response).to render_template :new
      end
    end

    it 'tracks an analytics event' do
      stub_analytics
      allow(@analytics).to receive(:track_event)

      get :new

      expect(@analytics).to have_received(:track_event).
        with(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_VISIT)
    end
  end

  describe '#create' do
    let(:params) { { otp_delivery_preference: :sms } }

    context 'user has not selected phone verification method' do
      before do
        subject.idv_session.address_verification_mechanism = 'usps'
      end

      it 'redirects to the review controller' do
        post :create, params: params
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user has confirmed phone number' do
      before do
        subject.idv_session.user_phone_confirmation = true
      end

      it 'redirects to the review controller' do
        post :create, params: params
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user has not completed phone step' do
      before do
        subject.idv_session.vendor_phone_confirmation = false
      end

      it 'redirects to the phone controller' do
        post :create, params: params
        expect(response).to redirect_to idv_phone_path
      end
    end

    context 'user has selected sms' do
      it 'redirects to the otp send path for sms' do
        post :create, params: params
        expect(subject.idv_session.phone_confirmation_otp_delivery_method).to eq('sms')
        expect(response).to redirect_to idv_otp_verification_path
      end

      it 'tracks an analytics event' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        post :create, params: params

        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, result)
      end
    end

    context 'user has selected voice' do
      let(:params) { { otp_delivery_preference: :voice } }

      it 'redirects to the otp send path for voice' do
        post :create, params: params
        expect(subject.idv_session.phone_confirmation_otp_delivery_method).to eq('voice')
        expect(response).to redirect_to idv_otp_verification_path
      end

      it 'tracks an analytics event' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        post :create, params: params

        result = {
          success: true,
          errors: {},
          otp_delivery_preference: 'voice',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, result)
      end
    end

    context 'form is invalid' do
      let(:params) { { otp_delivery_preference: :🎷 } }

      it 'renders the new template' do
        post :create, params: params
        expect(response).to render_template :new
      end

      it 'tracks an analytics event' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        post :create, params: params

        result = {
          success: false,
          errors: { otp_delivery_preference: ['is not included in the list'] },
          otp_delivery_preference: '🎷',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, result)
      end
    end

    context 'the telephony gem raises an exception' do
      let(:telephony_error_analytics_hash) do
        {
          error: 'Telephony::TelephonyError',
          message: 'error message',
          context: 'idv',
          country: 'US',
        }
      end
      let(:telephony_error) do
        Telephony::TelephonyError.new('error message')
      end

      before do
        stub_analytics
        allow(Telephony).to receive(:send_confirmation_otp).and_raise(telephony_error)
      end

      it 'tracks an analytics events' do
        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, hash_including(success: true)
        )
        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::TWILIO_PHONE_VALIDATION_FAILED, telephony_error_analytics_hash
        )

        post :create, params: params
      end
    end
  end
end
