require 'rails_helper'

RSpec.describe SignUp::WebauthnPlatformSetupController do
  let(:user) { create(:user) }

  before do
    stub_sign_in_before_2fa(user)
  end

  describe 'before_actions' do
    it 'includes performs all actions' do
      expect(controller).to have_actions(
        :before,
        :confirm_user_authenticated_for_2fa_setup,
        :apply_secure_headers_override,
      )
    end
  end

  describe '#new' do
    before { stub_analytics }

    context 'when user is in the auto_passkey_prompt bucket' do
      before do
        allow(controller).to receive(:ab_test_bucket).with(:PASSKEY_UPSELL)
          .and_return(:auto_passkey_prompt)
        allow(WebAuthn::Credential).to receive(:options_for_create).and_return(
          instance_double(
            WebAuthn::PublicKeyCredential::CreationOptions,
            challenge: SecureRandom.random_bytes(32),
          ),
        )
      end

      it 'logs analytics with the bucket' do
        get :new

        expect(@analytics).to have_logged_event(
          :webauthn_platform_signup_setup_ab_test_visited,
          passkey_upsell_bucket: :auto_passkey_prompt,
        )
      end

      it 'renders the shared webauthn setup page with auto-trigger on page load' do
        get :new

        expect(response).to render_template('users/webauthn_setup/new')
        expect(assigns(:auto_trigger)).to be(true)
        expect(assigns(:platform_authenticator)).to be(true)
      end

      it 'marks the passkey prompt as already shown' do
        get :new

        expect(controller.user_session[:auto_passkey_prompted]).to eq(true)
      end

      it 'saves the webauthn challenge in the session' do
        get :new

        expect(controller.user_session[:webauthn_challenge]).to be_present
      end
    end

    context 'when user is in the passkey_setup_prompt_after_password_creation bucket' do
      before do
        allow(controller).to receive(:ab_test_bucket).with(:PASSKEY_UPSELL)
          .and_return(:passkey_setup_prompt_after_password_creation)
      end

      it 'logs analytics with the bucket' do
        get :new

        expect(@analytics).to have_logged_event(
          :webauthn_platform_signup_setup_ab_test_visited,
          passkey_upsell_bucket: :passkey_setup_prompt_after_password_creation,
        )
      end

      it 'renders the upsell page without triggering webauthn' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'marks the passkey prompt as already shown' do
        get :new

        expect(controller.user_session[:auto_passkey_prompted]).to eq(true)
      end
    end

    context 'when user already has a platform authenticator' do
      let(:user) { create(:user, :with_webauthn_platform) }

      before do
        allow(controller).to receive(:user_fully_authenticated?).and_return(true)
      end

      it 'redirects to authentication methods setup' do
        get :new

        expect(response).to redirect_to(authentication_methods_setup_path)
      end
    end
  end

  describe '#create' do
    before do
      stub_analytics
      allow(controller).to receive(:ab_test_bucket).with(:PASSKEY_UPSELL)
        .and_return(:passkey_setup_prompt_after_password_creation)
      allow(WebAuthn::Credential).to receive(:options_for_create).and_return(
        instance_double(
          WebAuthn::PublicKeyCredential::CreationOptions,
          challenge: SecureRandom.random_bytes(32),
        ),
      )
    end

    it 'logs analytics with the bucket' do
      post :create

      expect(@analytics).to have_logged_event(
        :webauthn_platform_signup_setup_ab_test_submitted,
        passkey_upsell_bucket: :passkey_setup_prompt_after_password_creation,
      )
    end

    it 'renders the shared webauthn setup page without auto-trigger' do
      post :create

      expect(response).to render_template('users/webauthn_setup/new')
      expect(assigns(:auto_trigger)).to be(false)
      expect(assigns(:platform_authenticator)).to be(true)
    end

    it 'sets the signup recommended and prompt-shown session flags' do
      post :create

      expect(controller.user_session[:webauthn_platform_signup_setup_recommended]).to eq(true)
      expect(controller.user_session[:auto_passkey_prompted]).to eq(true)
    end

    it 'saves the webauthn challenge in the session' do
      post :create

      expect(controller.user_session[:webauthn_challenge]).to be_present
    end
  end
end
