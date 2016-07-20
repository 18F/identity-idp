require 'rails_helper'

describe Users::OmniauthCallbacksController, devise: true do
  render_views

  def configure_valid_omniauth_login
    OmniAuthSpecHelper.valid_saml_login_setup('email@example.com', '1234')

    configure_request_env
  end

  def configure_invalid_omniauth_email
    OmniAuthSpecHelper.valid_saml_login_setup('invalid_email', '1234')

    configure_request_env
  end

  def configure_request_env
    request.env['devise.mapping'] = Devise.mappings[:user]
    request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:saml]
  end

  describe 'GET /users/auth/saml/callback' do
    context 'when the authorization is valid' do
      before do
        configure_valid_omniauth_login
        get :saml
      end

      it 'signs the user in and redirects to profile' do
        expect(controller.user_signed_in?).to eq true
        expect(response).to redirect_to(profile_path)
      end

      it 'displays a success notice' do
        expect(flash[:notice]).to eq t('devise.omniauth_callbacks.success')
      end
    end

    context 'when the authorization is invalid' do
      before do
        configure_invalid_omniauth_email
        get :saml
      end

      it 'does not sign the user in and redirects to login page' do
        expect(controller.signed_in?).to eq false
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'displays an error alert' do
        expect(flash[:alert]).
          to eq t('devise.omniauth_callbacks.failure', reason: 'Invalid email')
      end
    end

    context 'allow third party auth feature disabled' do
      before do
        configure_valid_omniauth_login

        allow(FeatureManagement).to receive(:allow_third_party_auth?).and_return(false)

        get :saml
      end

      it 'is unauthorized' do
        expect(response.status).to eq(401)
      end

      it 'does not redirect anywhere' do
        expect(response).to_not be_redirect
      end
    end
  end
end
