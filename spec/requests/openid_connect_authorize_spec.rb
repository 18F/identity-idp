require 'rails_helper'

describe 'user signs in partially and visits openid_connect/authorize' do
  let(:user) { create(:user, :signed_up, phone: '+1 (202) 555-1213') }

  it 'prompts the user to 2FA' do
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    state = SecureRandom.hex
    nonce = SecureRandom.hex

    post new_user_session_path, params: { user: { email: user.email, password: user.password } }
    follow_redirect!
    get(
      openid_connect_authorize_path,
      params: {
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email profile:name social_security_number',
        redirect_uri: 'http://localhost:7654/auth/result',
        state: state,
        prompt: 'select_account',
        nonce: nonce,
      },
      headers: { 'Accept' => '*/*' }
    )
    follow_redirect!
    expect(response).
      to redirect_to login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
  end
end
