require 'rails_helper'

describe Idv::OtpVerificationController do
  let(:user) { create(:user) }

  let(:phone) { '2255555000' }
  let(:user_phone_confirmation) { false }
  let(:phone_confirmation_otp_code) { '777777' }
  let(:phone_confirmation_otp_sent_at) { Time.zone.now }
  let(:phone_confirmation_session_properties) do
    {
      code: phone_confirmation_otp_code,
      phone: phone,
      delivery_method: :sms,
    }
  end
  let(:user_phone_confirmation_session) do
    Idv::PhoneConfirmationSession.new(
      **phone_confirmation_session_properties,
      sent_at: phone_confirmation_otp_sent_at,
    )
  end

  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.applicant[:phone] = phone
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.user_phone_confirmation_session = user_phone_confirmation_session
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#show' do
    context 'the user has not been sent an otp' do
      let(:user_phone_confirmation_session) { nil }

      it 'redirects to the delivery method path' do
        get :show
        expect(response).to redirect_to(idv_phone_url)
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
        'IdV: phone confirmation otp visited',
        proofing_components: nil,
      )
    end
  end

  describe '#update' do
    let(:otp_code_param) { { code: phone_confirmation_otp_code } }
    context 'the user has not been sent an otp' do
      let(:user_phone_confirmation_session) { nil }

      it 'redirects to otp delivery method selection' do
        put :update, params: otp_code_param
        expect(response).to redirect_to(idv_phone_url)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        put :update, params: otp_code_param
        expect(response).to redirect_to(idv_review_path)
      end
    end

    it 'tracks an analytics event' do
      put :update, params: otp_code_param

      expected_result = {
        success: true,
        errors: {},
        code_expired: false,
        code_matches: true,
        second_factor_attempts_count: 0,
        second_factor_locked_at: nil,
        proofing_components: nil,
      }

      expect(@analytics).to have_received(:track_event).with(
        'IdV: phone confirmation otp submitted',
        expected_result,
      )
    end
  end
end
