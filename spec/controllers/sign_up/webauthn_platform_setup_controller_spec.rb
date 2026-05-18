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
    it 'logs analytics value' do
      stub_analytics

      get :new

      expect(@analytics).to have_logged_event(:webauthn_platform_signup_setup_visited)
    end
  end

  describe '#create' do
    before do
      stub_analytics
    end

    context 'when the user opts out of adding webauthn platform' do
      it 'logs accordingly' do
        post :create

        expect(@analytics).to have_logged_event(
          :webauthn_platform_signup_setup_submitted,
          opted_to_add: false,
        )
      end

      it 'does not set webauthn_platform_signup_setup_recommended in session' do
        post :create

        expect(controller.user_session[:webauthn_platform_signup_setup_recommended]).to be_nil
      end

      it 'redirects to authentication_methods_setup' do
        post :create

        response

        expect(response).to redirect_to(authentication_methods_setup_url)
      end
    end

    context 'when the user opts in to add webauthn platform' do
      it 'logs analytics accordingly' do
        post :create, params: { add_webauthn_platform: true }

        expect(@analytics).to have_logged_event(
          :webauthn_platform_signup_setup_submitted,
          opted_to_add: true,
        )
      end

      it 'sets webauthn_platform_signup_setup_recommended to true in session' do
        post :create, params: { add_webauthn_platform: true }

        expect(controller.user_session[:webauthn_platform_signup_setup_recommended]).to eq true
      end

      it 'redirects to webauthn platform setup url' do
        post :create, params: { add_webauthn_platform: true }

        response

        expect(response).to redirect_to(webauthn_setup_path(platform: true, auto_trigger: true))
      end
    end
  end
end
