require_relative 'features/javascript_driver_helper'

module OidcAuthHelper
  include JavascriptDriverHelper

  OIDC_ISSUER = 'urn:gov:gsa:openidconnect:sp:server'.freeze
  OIDC_IAL1_ISSUER = 'urn:gov:gsa:openidconnect:sp:server_ial1'.freeze
  OIDC_AAL3_ISSUER = 'urn:gov:gsa:openidconnect:sp:server_requiring_aal3'.freeze

  def sign_in_oidc_user(user)
    visit_idp_from_ial1_oidc_sp
    fill_in_credentials_and_submit(user.email, user.password)
    click_submit_default
  end

  def visit_idp_from_ial1_oidc_sp(**args)
    params = ial1_params(**args)
    oidc_path = openid_connect_authorize_path params
    visit oidc_path
    oidc_path
  end

  def visit_idp_from_oidc_sp_with_vtr(vtr:, **args)
    params = vtr_params(vtr: vtr, **args)
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

  def ial1_params(
    prompt: nil,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    client_id: OIDC_IAL1_ISSUER
  )
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

  def ial2_params(
    prompt: nil,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    client_id: OIDC_ISSUER,
    acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
    facial_match_required: false
  )
    ial2_params = {
      client_id: client_id,
      response_type: 'code',
      scope: 'openid email profile:name social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    ial2_params[:prompt] = prompt if prompt

    if facial_match_required
      ial2_params[:acr_values] = Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
    else
      ial2_params[:acr_values] = acr_values
    end

    ial2_params
  end

  def vtr_params(
    vtr:,
    prompt: nil,
    state: SecureRandom.hex,
    nonce: SecureRandom.hex,
    client_id: OIDC_ISSUER,
    scope: 'openid email profile:name social_security_number'
  )
    vtr_params = {
      client_id: client_id,
      response_type: 'code',
      vtr: vtr.to_json,
      scope: scope,
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      nonce: nonce,
    }
    vtr_params[:prompt] = prompt if prompt
    vtr_params
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

  def extract_redirect_url
    page.find_link(t('forms.buttons.submit.default'))[:href]
  end

  def oidc_redirect_url
    # Page will redirect automatically if JavaScript is enabled
    return current_url if javascript_enabled?

    case IdentityConfig.store.openid_connect_redirect
    when 'client_side'
      extract_meta_refresh_url
    when 'client_side_js'
      extract_redirect_url
    else # should only be :server_side
      current_url
    end
  end

  def oidc_decoded_token
    return @oidc_decoded_token if defined?(@oidc_decoded_token)
    redirect_uri = URI(oidc_redirect_url)
    redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access
    code = redirect_params[:code]

    jwt_payload = {
      iss: 'urn:gov:gsa:openidconnect:sp:server',
      sub: 'urn:gov:gsa:openidconnect:sp:server',
      aud: api_openid_connect_token_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
    }

    client_private_key = OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys', 'saml_test_sp.key')),
    )
    client_assertion = JWT.encode(jwt_payload, client_private_key, 'RS256')
    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

    Capybara.using_driver(:desktop_rack_test) do
      page.driver.post(
        api_openid_connect_token_url,
        grant_type: 'authorization_code',
        code:,
        client_assertion_type:,
        client_assertion:,
      )
      @oidc_decoded_token = JSON.parse(page.body).with_indifferent_access
    end
  end

  def oidc_decoded_id_token
    @oidc_decoded_id_token ||= JWT.decode(
      oidc_decoded_token[:id_token],
      AppArtifacts.store.oidc_primary_public_key,
      true,
      algorithm: 'RS256',
    ).first.with_indifferent_access
  end
end
