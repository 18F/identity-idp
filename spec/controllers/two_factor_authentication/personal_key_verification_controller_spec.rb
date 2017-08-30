require 'rails_helper'

describe TwoFactorAuthentication::PersonalKeyVerificationController do
  let(:personal_key) { { personal_key: 'foo' } }
  let(:payload) { { personal_key_form: personal_key } }

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
    context 'when the user enters a valid personal key' do
      before do
        stub_sign_in_before_2fa(build(:user, personal_key: 'foo'))
        form = instance_double(PersonalKeyForm)
        response = FormResponse.new(
          success: true, errors: {}, extra: { multi_factor_auth_method: 'personal key' }
        )
        allow(PersonalKeyForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'redirects to the profile' do
        post :create, params: payload

        expect(response).to redirect_to account_path
      end

      it 'calls handle_valid_otp' do
        expect(subject).to receive(:handle_valid_otp).and_call_original

        post :create, params: payload
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        analytics_hash = { success: true, errors: {}, multi_factor_auth_method: 'personal key' }

        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH, analytics_hash)

        post :create, params: payload
      end
    end

    context 'when the personal key field is empty' do
      let(:personal_key) { { personal_key: '' } }
      let(:payload) { { personal_key_form: personal_key } }

      before do
        stub_sign_in_before_2fa(build(:user, phone: '+1 (703) 555-1212'))
        form = instance_double(PersonalKeyForm)
        response = FormResponse.new(
          success: false, errors: {}, extra: { multi_factor_auth_method: 'personal key' }
        )
        allow(PersonalKeyForm).to receive(:new).
          with(subject.current_user, '').and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'renders the show page' do
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_personal_key')
      end
    end

    context 'when the user enters an invalid personal key' do
      before do
        stub_sign_in_before_2fa(build(:user, phone: '+1 (703) 555-1212'))
        form = instance_double(PersonalKeyForm)
        response = FormResponse.new(
          success: false, errors: {}, extra: { multi_factor_auth_method: 'personal key' }
        )
        allow(PersonalKeyForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'calls handle_invalid_otp' do
        expect(subject).to receive(:handle_invalid_otp).and_call_original

        post :create, params: payload
      end

      it 're-renders the personal key entry screen' do
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_personal_key')
      end

      it 'tracks the max attempts event' do
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        properties = {
          success: false,
          errors: {},
          multi_factor_auth_method: 'personal key',
        }

        stub_analytics

        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH, properties)
        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

        post :create, params: payload
      end
    end
  end
end
