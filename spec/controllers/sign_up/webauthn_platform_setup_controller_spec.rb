require 'rails_helper'

RSpec.describe SignUp::WebauthnPlatformSetupController do
  include WebAuthnHelper

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

      expect(@analytics).to have_logged_event(:webauthn_platform_signup_setup_ab_test_visited)
    end
  end

  describe '#confirm' do
    let(:user) { create(:user) }
    let(:params) do
      {
        attestation_object: attestation_object,
        client_data_json: setup_client_data_json,
        name: 'mykey',
        transports: 'usb',
      }
    end

    before do
      stub_analytics
      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
      request.host = 'localhost:3000'
      controller.user_session[:webauthn_challenge] = webauthn_challenge
      mock_webauthn_setup_challenge
    end

    context 'analytics' do
      it 'logs ebauthn_platform_signup_setup_ab_test_submitted accordingly' do
        patch :confirm, params: params

        expect(@analytics).to have_logged_event(:webauthn_platform_signup_setup_ab_test_submitted)
      end

      it 'logs multi_factor_auth_setup event accordingly' do
        patch :confirm, params: params

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication Setup',
          hash_including(
            in_account_creation_flow: true,
            success: true,
            multi_factor_auth_method: 'webauthn_platform',
          ),
        )
      end
    end

    context 'on successful submission' do
      it 'redirects to authentication_methods_setup_path' do
        patch :confirm, params: params

        expect(response).to redirect_to(authentication_methods_setup_path)
      end

      it 'creates a webauthn configuration for the user' do
        expect do
          patch :confirm,
                params: params
        end.to change { user.webauthn_configurations.count }.by(1)
      end
    end
  end
end
