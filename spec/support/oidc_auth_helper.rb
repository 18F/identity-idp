module OidcAuthHelper
  OIDC_ISSUER = 'urn:gov:gsa:openidconnect:sp:server'.freeze

  def sign_in_oidc_user(user)
    visit_idp_from_ial1_oidc_sp
    fill_in_credentials_and_submit(user.email, user.password)
    click_continue
  end

  def visit_idp_from_ial1_oidc_sp(**args)
    params = ial1_params args
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_ial2_oidc_sp(**args)
    params = ial2_params args
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def ial1_params(prompt: nil,
                  state: SecureRandom.hex,
                  nonce: SecureRandom.hex,
                  client_id: OIDC_ISSUER)
    ial1_params = {
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    ial1_params[:prompt] = prompt if prompt
    ial1_params
  end

  def ial2_params(prompt: nil,
                  state: SecureRandom.hex,
                  nonce: SecureRandom.hex,
                  client_id: OIDC_ISSUER)
    ial2_params = {
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    ial2_params[:prompt] = prompt if prompt
    ial2_params
  end
end
