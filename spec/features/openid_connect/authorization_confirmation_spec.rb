require 'rails_helper'

feature 'OIDC Authorization Confirmation' do
  before do
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('9999')
  end

  context 'authenticated user signs in to new sp' do
    def create_user_and_remember_device
      user = user_with_2fa

      sign_in_oidc_user(user)
      check :remember_device
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_continue

      visit sign_out_url

      user
    end

    let(:user1) { create_user_and_remember_device }
    let(:user2) { create_user_and_remember_device }

    before do
      # Cycle user2 first so user1's remember device will stick
      user2
      user1
    end

    it 'it confirms the user wants to continue to the SP after signing in again' do
      sign_in_user(user1)
      visit_idp_from_oidc_sp
      expect(current_url).to match(user_authorization_confirmation_path)

      continue_as(user1.email)
      expect(current_url).to match('http://localhost:7654/auth/result')
    end

    it 'it allows the user to switch accounts prior to continuing to the SP' do
      sign_in_user(user1)
      visit_idp_from_oidc_sp
      expect(current_url).to match(user_authorization_confirmation_path)

      continue_as(user2.email, user2.password)

      # Can't remember both users' devices?
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to match('http://localhost:7654/auth/result')
    end
  end

  def sign_in_oidc_user(user)
    visit_idp_from_oidc_sp
    fill_in_credentials_and_submit(user.email, user.password)
    click_continue
  end

  def visit_idp_from_oidc_sp
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    state = SecureRandom.hex
    nonce = SecureRandom.hex

    params = {
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    visit openid_connect_authorize_path(params)
  end
end
