require 'rails_helper'

require 'omniauth_spec_helper'

describe "GET '/users/auth/saml/callback'" do
  def configure_valid_omniauth_login
    OmniAuth.config.mock_auth[:saml] = nil
    OmniAuthSpecHelper.valid_saml_login_setup('user@example.com', '1234')
  end

  def visit_omniauth_callback
    OmniAuthSpecHelper.silence_omniauth do
      get '/users/auth/saml/callback'
    end

    env = request.env
    env['devise.mapping'] = Devise.mappings[:user]
    env['omniauth.auth'] = OmniAuth.config.mock_auth[:saml]
  end

  context 'invalid credentials' do
    before do
      OmniAuthSpecHelper.invalid_credentials

      visit_omniauth_callback
    end

    it 'redirects to login page' do
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'displays a failure notice' do
      expect(flash[:alert]).
        to eq t('devise.omniauth_callbacks.failure', reason: 'Invalid credentials')
    end
  end

  context 'invalid ticket' do
    before do
      OmniAuthSpecHelper.invalid_ticket

      visit_omniauth_callback
    end

    it 'redirects to login page' do
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'displays a failure notice' do
      expect(flash[:alert]).
        to eq t('devise.omniauth_callbacks.failure', reason: 'Invalid ticket')
    end
  end
end
