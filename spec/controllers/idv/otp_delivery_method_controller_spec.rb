require 'rails_helper'

describe Idv::OtpDeliveryMethodController do
  let(:user) { build(:user) }

  before do
    stub_verify_steps_one_and_two(user)
    subject.idv_session.address_verification_mechanism = 'phone'
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = false
    user_phone_confirmation_session = PhoneConfirmation::ConfirmationSession.start(
      phone: '+1 (225) 555-5000',
      delivery_method: :sms,
    )
    subject.idv_session.user_phone_confirmation_session = user_phone_confirmation_session
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#new' do
    context 'user has not selected phone verification method' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
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
        with('IdV: Phone OTP delivery Selection Visited')
    end
  end

  describe '#create' do
    let(:params) { { otp_delivery_preference: :sms } }

    context 'user has not selected phone verification method' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
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
        expect(subject.idv_session.user_phone_confirmation_session.delivery_method).to eq(:sms)
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
          with('IdV: Phone OTP Delivery Selection Submitted', result)
      end
    end

    context 'user has selected voice' do
      let(:params) { { otp_delivery_preference: :voice } }

      it 'redirects to the otp send path for voice' do
        post :create, params: params
        expect(subject.idv_session.user_phone_confirmation_session.delivery_method).to eq(:voice)
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
          with('IdV: Phone OTP Delivery Selection Submitted', result)
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
          error_details: { otp_delivery_preference: [:inclusion] },
          otp_delivery_preference: '🎷',
        }

        expect(@analytics).to have_received(:track_event).
          with('IdV: Phone OTP Delivery Selection Submitted', result)
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
      let(:telephony_response) do
        Telephony::Response.new(
          success: false,
          error: telephony_error,
          extra: { request_id: 'error-request-id' },
        )
      end

      before do
        stub_analytics
        allow(Telephony).to receive(:send_confirmation_otp).and_return(telephony_response)
      end

      it 'tracks an analytics events' do
        expect(@analytics).to receive(:track_event).ordered.with(
          'IdV: Phone OTP Delivery Selection Submitted', hash_including(success: true)
        )
        expect(@analytics).to receive(:track_event).ordered.with(
          'IdV: phone confirmation otp sent',
          hash_including(
            success: false,
            telephony_response: telephony_response,
          ),
        )
        expect(@analytics).to receive(:track_event).ordered.with(
          'Vendor Phone Validation failed', telephony_error_analytics_hash
        )

        post :create, params: params
      end
    end
  end
end
