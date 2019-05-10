require 'rails_helper'

describe 'user signs in partially and visits openid_connect/authorize' do
  let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1213' }) }

  it 'prompts the user to 2FA' do
    openid_test('select_account')
    follow_redirect!
    expect(response).
      to redirect_to login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
  end

  it 'prompts the user to 2FA if prompt is login' do
    openid_test('login')
    sp_request_id = ServiceProviderRequest.last.uuid
    expect(response).to redirect_to new_user_session_path(request_id: sp_request_id)
  end

  it 'prompts the user to 2FA if prompt is not given' do
    openid_test
    follow_redirect!
    expect(response).
      to redirect_to login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
  end

  def openid_test(prompt = nil)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    state = SecureRandom.hex
    nonce = SecureRandom.hex

    post new_user_session_path, params: { user: { email: user.email, password: user.password } }
    follow_redirect!
    params = {
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    params[:prompt] = prompt if prompt
    get(
      openid_connect_authorize_path,
      params: params,
      headers: { 'Accept' => '*/*' },
    )
  end
end
