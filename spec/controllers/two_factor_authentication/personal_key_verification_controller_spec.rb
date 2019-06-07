require 'rails_helper'

describe TwoFactorAuthentication::PersonalKeyVerificationController do
  let(:ga_client_id) { '123.456' }
  let(:ga_cookie) { 'GA1.2.123.456' }
  let(:personal_key) { { personal_key: 'foo' } }
  let(:payload) { { personal_key_form: personal_key, ga_client_id: ga_client_id } }

  before do
    cookies['_ga'] = ga_cookie
  end

  describe '#show' do
    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it 'tracks the page visit' do
      stub_sign_in_before_2fa
      stub_analytics
      analytics_hash = { context: 'authentication' }

      expect(@analytics).to receive(:track_event).
        with(Analytics::MULTI_FACTOR_AUTH_ENTER_PERSONAL_KEY_VISIT, analytics_hash)

      get :show
    end
  end

  describe '#create' do
    context 'when the user enters a valid personal key' do
      it 'tracks the valid authentication event' do
        sign_in_before_2fa(create(:user, :with_webauthn))

        form = instance_double(PersonalKeyForm)
        response = FormResponse.new(
          success: true, errors: {}, extra: { multi_factor_auth_method: 'personal-key' },
        )
        allow(PersonalKeyForm).to receive(:new).
          with(subject.current_user, 'foo').and_return(form)
        allow(form).to receive(:submit).and_return(response)

        stub_analytics
        analytics_hash = { success: true, errors: {}, multi_factor_auth_method: 'personal-key' }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(analytics_hash, ga_client_id)

        expect(@analytics).to receive(:track_event).
          with(Analytics::USER_MARKED_AUTHED, authentication_type: :valid_2fa)

        post :create, params: payload
      end
    end

    it 'does not generate a new personal key after the user signs in with their old one' do
      user = create(:user)
      raw_key = PersonalKeyGenerator.new(user).create
      old_key = user.reload.encrypted_recovery_code_digest
      stub_sign_in_before_2fa(user)
      post :create, params: { personal_key_form: { personal_key: raw_key } }
      user.reload

      expect(user.encrypted_recovery_code_digest).to be_nil
      expect(user.encrypted_recovery_code_digest).to_not eq old_key
    end

    context 'when the personal key field is empty' do
      let(:personal_key) { { personal_key: '' } }
      let(:payload) { { personal_key_form: personal_key } }

      before do
        stub_sign_in_before_2fa(build(:user, :with_phone, with: { phone: '+1 (703) 555-1212' }))
        form = instance_double(PersonalKeyForm)
        response = FormResponse.new(
          success: false, errors: {}, extra: { multi_factor_auth_method: 'personal-key' },
        )
        allow(PersonalKeyForm).to receive(:new).
          with(subject.current_user, '').and_return(form)
        allow(form).to receive(:submit).and_return(response)
      end

      it 'renders the show page' do
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_personal_key')
      end
    end

    context 'when the user enters an invalid personal key' do
      before do
        stub_sign_in_before_2fa(build(:user, :with_phone, with: { phone: '+1 (703) 555-1212' }))
        form = instance_double(PersonalKeyForm)
        response = FormResponse.new(
          success: false, errors: {}, extra: { multi_factor_auth_method: 'personal-key' },
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
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_personal_key')
      end

      it 'tracks the max attempts event' do
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        properties = {
          success: false,
          errors: {},
          multi_factor_auth_method: 'personal-key',
        }

        stub_analytics

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties, ga_client_id)
        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

        post :create, params: payload
      end
    end

    it 'does not generate a new personal key if the user enters an invalid key' do
      user = create(:user, :with_personal_key)
      old_key = user.reload.encrypted_recovery_code_digest
      stub_sign_in_before_2fa(user)
      post :create, params: payload
      user.reload

      expect(user.encrypted_recovery_code_digest).to eq old_key
    end
  end
end
