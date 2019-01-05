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

    context 'twilio raises an exception' do
      let(:twilio_error_analytics_hash) do
        {
          error: "[HTTP 400]  : error message\n\n",
          code: '',
          context: 'idv',
          country: 'US',
        }
      end
      let(:twilio_error) do
        Twilio::REST::RestError.new('error message', FakeTwilioErrorResponse.new)
      end

      before do
        stub_analytics
        allow(SmsOtpSenderJob).to receive(:perform_later).and_raise(twilio_error)
      end

      context 'twilio rest error' do
        it 'tracks an analytics events' do
          expect(@analytics).to receive(:track_event).ordered.with(
            Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, hash_including(success: true)
          )
          expect(@analytics).to receive(:track_event).ordered.with(
            Analytics::TWILIO_PHONE_VALIDATION_FAILED, twilio_error_analytics_hash
          )

          post :create, params: params
        end
      end

      context 'phone verification verify error' do
        let(:twilio_error_analytics_hash) do
          analytics_hash = super()
          analytics_hash.merge(
            error: 'error',
            code: 60_033,
            status: 400,
            response: '{"error_code":"60004"}'
          )
        end
        let(:twilio_error) do
          PhoneVerification::VerifyError.new(
            code: 60_033,
            message: 'error',
            status: 400,
            response:  '{"error_code":"60004"}'
          )
        end

        it 'tracks an analytics event' do
          expect(@analytics).to receive(:track_event).ordered.with(
            Analytics::IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED, hash_including(success: true)
          )
          expect(@analytics).to receive(:track_event).ordered.with(
            Analytics::TWILIO_PHONE_VALIDATION_FAILED, twilio_error_analytics_hash
          )

          post :create, params: params
        end
      end
    end
  end
end
