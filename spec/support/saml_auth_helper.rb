require 'saml_idp_constants'

## GET /api/saml/auth helper methods
module SamlAuthHelper
  def saml_settings(overrides: {})
    settings = OneLogin::RubySaml::Settings.new

    # SP settings
    settings.assertion_consumer_service_url = 'http://localhost:3000/test/saml/decode_assertion'
    settings.assertion_consumer_logout_service_url = 'http://localhost:3000/test/saml/decode_slo_request'
    settings.authn_context = request_authn_contexts
    settings.certificate = saml_test_sp_cert
    settings.private_key = saml_test_sp_key
    settings.name_identifier_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT

    # SP + IdP Settings
    settings.issuer = 'http://localhost:3000'
    settings.security[:authn_requests_signed] = true
    settings.security[:logout_requests_signed] = true
    settings.security[:embed_sign] = true
    settings.security[:digest_method] = 'http://www.w3.org/2001/04/xmlenc#sha256'
    settings.security[:signature_method] = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
    settings.double_quote_xml_attribute_values = true

    # IdP setting
    settings.idp_sso_target_url = "http://#{IdentityConfig.store.domain_name}/api/saml/auth2022"
    settings.idp_slo_target_url = "http://#{IdentityConfig.store.domain_name}/api/saml/logout2022"
    settings.idp_cert_fingerprint = idp_fingerprint
    settings.idp_cert_fingerprint_algorithm = 'http://www.w3.org/2001/04/xmlenc#sha256'

    overrides.except(:security).each do |setting, value|
      settings.send("#{setting}=", value)
    end
    settings.security.merge!(overrides[:security]) if overrides[:security]
    settings
  end

  def request_authn_contexts
    [
      Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
    ]
  end

  def saml_test_sp_cert
    @saml_test_sp_cert ||= File.read(Rails.root.join('certs', 'sp', 'saml_test_sp.crt'))
  end

  def saml_test_sp_cert_serial
    OpenSSL::X509::Certificate.new(saml_test_sp_cert).serial.to_s
  end

  def idp_fingerprint
    @idp_fingerprint ||= Fingerprinter.fingerprint_cert(
      OpenSSL::X509::Certificate.new(saml_test_idp_cert),
    )
  end

  def auth_request
    @auth_request ||= OneLogin::RubySaml::Authrequest.new
  end

  def logout_request
    @logout_request ||= OneLogin::RubySaml::Logoutrequest.new
  end

  def saml_authn_request_url(overrides: {}, params: {})
    @saml_authn_request = auth_request.create(
      saml_settings(overrides: overrides),
      params,
    )
  end

  def saml_logout_request_url(overrides: {}, params: {})
    logout_request.create(
      saml_settings(overrides: overrides),
      params,
    )
  end

  def saml_remote_logout_request_url(overrides: {}, params: {})
    overrides[:idp_slo_target_url] = "http://#{IdentityConfig.store.domain_name}/api/saml/remotelogout2022"
    logout_request.create(
      saml_settings(overrides: overrides),
      params,
    )
  end

  def visit_saml_authn_request_url(overrides: {}, params: {})
    authn_request_url = saml_authn_request_url(overrides: overrides, params: params)
    visit authn_request_url
  end

  def visit_saml_logout_request_url(overrides: {}, params: {})
    logout_request_url = saml_logout_request_url(overrides: overrides, params: params)
    visit logout_request_url
  end

  def send_saml_remote_logout_request(overrides: {}, params: {})
    remote_logout_request_url = saml_remote_logout_request_url(overrides: overrides, params: params)
    page.driver.post remote_logout_request_url
  end

  def saml_get_auth(settings)
    request.headers.merge!({ HTTP_REFERER: 'http://fake-sp.gov' })
    # GET redirect binding Authn Request
    get :auth, params: { SAMLRequest: CGI.unescape(saml_request(settings)) }
  end

  def saml_post_auth(saml_request)
    # POST redirect binding Authn Request
    request.headers.merge!({ HTTP_REFERER: api_saml_authpost2022_url })
    request.path = '/api/saml/authpost2021'
    post :auth, params: { SAMLRequest: CGI.unescape(saml_request) }
  end

  def saml_final_post_auth(saml_request)
    request.headers.merge!({ HTTP_REFERER: complete_saml_url })
    request.path = '/api/saml/finalauthpost2021'
    post :auth, params: { SAMLRequest: CGI.unescape(saml_request) }
  end

  private

  def saml_request(settings)
    authn_request(settings).split('SAMLRequest=').last
  end

  def saml_test_sp_key
    @saml_test_sp_key ||= OpenSSL::PKey::RSA.new(
      File.read(Rails.root + 'keys/saml_test_sp.key'),
    ).to_pem
  end

  def saml_test_idp_cert
    AppArtifacts.store.saml_2022_cert
  end

  public

  def sp1
    build(:service_provider, issuer: sp1_issuer)
  end

  def sp1_issuer
    'https://rp1.serviceprovider.com/auth/saml/metadata'
  end

  def sp2_issuer
    'https://rp2.serviceprovider.com/auth/saml/metadata'
  end

  def aal3_issuer
    'https://aal3.serviceprovider.com/auth/saml/metadata'
  end

  ##################################################################################################
  ##################################################################################################

  # generates a SAML response and returns a parsed Nokogiri XML document
  def generate_saml_response(user, settings = saml_settings, link: true)
    # user needs to be signed in in order to generate an assertion
    link_user_to_identity(user, link, settings)
    sign_in(user)
    saml_get_auth(settings)
  end

  # generates a SAML response and returns a decoded XML document
  def generate_decoded_saml_response(user, settings = saml_settings)
    auth_response = generate_saml_response(user, settings)
    decode_saml_response(auth_response)
  end

  def decode_saml_response(auth_response)
    saml_response_encoded = saml_response_encoded(auth_response)
    saml_response_text = Base64.decode64(saml_response_encoded)
    REXML::Document.new(saml_response_text)
  end

  def saml_response_encoded(auth_response)
    Nokogiri::HTML(auth_response.body).css('#SAMLResponse').first.attributes['value'].to_s
  end

  def saml_response_authn_context(decoded_saml_response)
    REXML::XPath.match(decoded_saml_response, '//AuthnContext/AuthnContextClassRef')[0][0]
  end

  private

  def link_user_to_identity(user, link, settings)
    return unless link

    IdentityLinker.new(
      user,
      build(:service_provider, issuer: settings.issuer),
    ).link_identity(
      ial: ial2_requested?(settings) ? true : nil,
      verified_attributes: ['email'],
    )
  end

  def ial2_requested?(settings)
    settings.authn_context != Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
  end

  # generate a SAML Authn request
  def authn_request(settings = saml_settings, params = {})
    OneLogin::RubySaml::Authrequest.new.create(settings, params)
  end

  # generates saml authn parameters for post
  def authn_request_post_params(settings = saml_settings, params = {})
    auth_params = OneLogin::RubySaml::Authrequest.new.create_params(settings, params)
    auth_params.merge(params)
    auth_params
  end

  def post_saml_authn_request(settings = saml_settings, params = {})
    saml_authn_params = authn_request_post_params(settings, params)
    page.driver.post(saml_settings.idp_sso_target_url, saml_authn_params)
    click_button(t('forms.buttons.submit.default'))
  end

  def login_and_confirm_sp(user, protocol)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    protocol == :saml ? click_submit_default_twice : click_submit_default

    expect(current_url).to match new_user_session_path
    expect(page).to have_content(t('titles.sign_up.completion_first_sign_in', sp: 'Test SP'))

    click_agree_and_continue
  end

  def visit_idp_from_sp_with_ial1(sp)
    if sp == :saml
      visit_saml_authn_request_url(
        overrides: { authn_context: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF },
      )
    elsif sp == :oidc
      @state = SecureRandom.hex
      @client_id = 'urn:gov:gsa:openidconnect:sp:server'
      @nonce = SecureRandom.hex
      visit_idp_from_oidc_sp_with_ial1(state: @state, client_id: @client_id, nonce: @nonce)
    end
  end

  def visit_idp_from_sp_with_ial1_aal2(sp)
    if sp == :saml
      visit_saml_authn_request_url(
        overrides: { authn_context: [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
        ] },
      )
    elsif sp == :oidc
      @state = SecureRandom.hex
      @client_id = 'urn:gov:gsa:openidconnect:sp:server'
      @nonce = SecureRandom.hex
      visit_idp_from_oidc_sp_with_ial1_aal2(state: @state, client_id: @client_id, nonce: @nonce)
    end
  end

  def visit_idp_from_oidc_sp_with_ial1(client_id:, nonce:, state: SecureRandom.hex)
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_oidc_sp_with_ial1_aal2(client_id:, nonce:, state: SecureRandom.hex)
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: [
        Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      ].join(' '),
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_oidc_sp_with_loa1_prompt_login
    state = SecureRandom.hex
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'login',
      nonce: nonce,
    )
  end

  def visit_idp_from_oidc_sp_with_hspd12_and_require_piv_cac
    state = SecureRandom.hex
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF + ' ' +
        Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email x509 x509:presented',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_saml_sp_with_ialmax
    visit_saml_authn_request_url(
      overrides: {
        issuer: 'saml_sp_ial2',
        authn_context: [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}ssn",
        ],
        authn_context_comparison: 'minimum',
      },
    )
  end

  def visit_idp_from_oidc_sp_with_ialmax
    state = SecureRandom.hex
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex
    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile:name social_security_number',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'login',
      nonce: nonce,
    )
  end
end
