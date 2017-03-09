require 'rails_helper'

describe TwoFactorAuthentication::RecoveryCodeVerificationController do
  let(:code) { { code: ['foo'] } }
  let(:payload) { { recovery_code_form: code } }

  describe '#show' do
    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe '#create' do
    context 'when the user enters a valid recovery code' do
      before do
        stub_sign_in_before_2fa(build(:user, recovery_code: 'foo'))
        form = instance_double(RecoveryCodeForm)
        response = FormResponse.new(success: true, errors: {}, extra: { method: 'recovery code' })
        allow(RecoveryCodeForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'redirects to the profile' do
        post :create, payload

        expect(response).to redirect_to profile_path
      end

      it 'calls handle_valid_otp' do
        expect(subject).to receive(:handle_valid_otp).and_call_original

        post :create, payload
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        analytics_hash = { success: true, errors: {}, method: 'recovery code' }

        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH, analytics_hash)

        post :create, payload
      end
    end

    context 'when the user enters an invalid recovery code' do
      before do
        stub_sign_in_before_2fa(build(:user, phone: '+1 (703) 555-1212'))
        form = instance_double(RecoveryCodeForm)
        response = FormResponse.new(success: false, errors: {}, extra: { method: 'recovery code' })
        allow(RecoveryCodeForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'calls handle_invalid_otp' do
        expect(subject).to receive(:handle_invalid_otp).and_call_original

        post :create, payload
      end

      it 're-renders the recovery code entry screen' do
        post :create, payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_recovery_code')
      end

      it 'tracks the max attempts event' do
        properties = {
          success: false,
          errors: {},
          method: 'recovery code',
        }

        stub_analytics

        expect(@analytics).to receive(:track_event).exactly(3).times.
          with(Analytics::MULTI_FACTOR_AUTH, properties)
        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

        3.times { post :create, payload }
      end
    end
  end
end
