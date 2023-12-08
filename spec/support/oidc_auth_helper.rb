module OidcAuthHelper
  OIDC_ISSUER = 'urn:gov:gsa:openidconnect:sp:server'.freeze
  OIDC_IAL1_ISSUER = 'urn:gov:gsa:openidconnect:sp:server_ial1'.freeze
  OIDC_AAL3_ISSUER = 'urn:gov:gsa:openidconnect:sp:server_requiring_aal3'.freeze

  def sign_in_oidc_user(user)
    visit_idp_from_ial1_oidc_sp
    fill_in_credentials_and_submit(user.email, user.password)
    click_continue
  end

  def visit_idp_from_ial1_oidc_sp(**args)
    params = ial1_params(**args)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_ial_max_oidc_sp(**args)
    args[:acr_values] = Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
    params = ial2_params(**args)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_ial2_oidc_sp(**args)
    params = ial2_params(**args)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_ial1_oidc_sp_requesting_aal3(**args)
    params = ial1_params(**args)
    include_aal3(params)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(**args)
    params = ial1_params(**args)
    include_phishing_resistant(params)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(**args)
    args[:client_id] ||= OIDC_AAL3_ISSUER
    params = ial1_params(**args)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def ial1_params(prompt: nil,
                  state: SecureRandom.hex,
                  nonce: SecureRandom.hex,
                  client_id: OIDC_IAL1_ISSUER,
                  tid: nil)
    ial1_params = {
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    ial1_params[:tid] = tid if tid
    ial1_params[:prompt] = prompt if prompt
    ial1_params
  end

  def ial2_params(prompt: nil,
                  state: SecureRandom.hex,
                  nonce: SecureRandom.hex,
                  client_id: OIDC_ISSUER,
                  acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                  tid: nil)
    ial2_params = {
      client_id: client_id,
      response_type: 'code',
      acr_values: acr_values,
      scope: 'openid email profile:name social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    ial2_params[:tid] = tid if tid
    ial2_params[:prompt] = prompt if prompt
    ial2_params
  end

  def include_phishing_resistant(params)
    params[:acr_values] = "#{params[:acr_values]} " +
                          Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF
  end

  def include_aal3(params)
    params[:acr_values] = "#{params[:acr_values]} " +
                          Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
  end

  # We rely on client-side redirects in some cases using:
  # <meta content="0;url=REDIRECT_URL" http-equiv="refresh" />
  # This method checks that the url contains the right url
  def extract_meta_refresh_url
    content = page.find("meta[http-equiv='refresh']", visible: false)['content']
    timeout, url_value = content.split(';')
    expect(timeout).to eq '0'
    _, url = url_value.split('url=')
    url
  end

  def oidc_redirect_url
    if IdentityConfig.store.openid_connect_redirect_interstitial_enabled
      extract_meta_refresh_url
    else
      current_url
    end
  end
end
