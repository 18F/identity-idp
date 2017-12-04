require 'saml_idp_constants'

## GET /api/saml/auth helper methods
module SamlAuthHelper
  def saml_settings
    settings = OneLogin::RubySaml::Settings.new

    # SP settings
    settings.assertion_consumer_service_url = 'http://localhost:3000/test/saml/decode_assertion'
    settings.assertion_consumer_logout_service_url = 'http://localhost:3000/test/saml/decode_slo_request'
    settings.certificate = saml_test_sp_cert
    settings.private_key = saml_test_sp_key
    settings.authn_context = Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF

    # SP + IdP Settings
    settings.issuer = 'http://localhost:3000'
    settings.security[:authn_requests_signed] = true
    settings.security[:logout_requests_signed] = true
    settings.security[:embed_sign] = true
    settings.security[:digest_method] = 'http://www.w3.org/2001/04/xmlenc#sha256'
    settings.security[:signature_method] = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
    settings.name_identifier_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
    settings.double_quote_xml_attribute_values = true
    # IdP setting
    settings.idp_sso_target_url = "http://#{Figaro.env.domain_name}/api/saml/auth"
    settings.idp_slo_target_url = "http://#{Figaro.env.domain_name}/api/saml/logout"
    settings.idp_cert_fingerprint = idp_fingerprint
    settings.idp_cert_fingerprint_algorithm = 'http://www.w3.org/2001/04/xmlenc#sha256'

    settings
  end

  def sp_fingerprint
    @sp_fingerprint ||= Fingerprinter.fingerprint_cert(
      OpenSSL::X509::Certificate.new(saml_test_sp_cert)
    )
  end

  def idp_fingerprint
    @idp_fingerprint ||= Fingerprinter.fingerprint_cert(
      OpenSSL::X509::Certificate.new(saml_test_idp_cert)
    )
  end

  def saml_test_sp_key
    @private_key ||= OpenSSL::PKey::RSA.new(
      File.read(Rails.root + 'keys/saml_test_sp.key')
    ).to_pem
  end

  def saml_test_idp_cert
    @saml_test_idp_cert ||= File.read(Rails.root.join('certs', 'saml.crt'))
  end

  def saml_test_sp_cert
    @saml_test_sp_cert ||= File.read(Rails.root.join('certs', 'sp', 'saml_test_sp.crt'))
  end

  def auth_request
    @auth_request ||= OneLogin::RubySaml::Authrequest.new
  end

  def authnrequest_get
    auth_request.create(saml_spec_settings)
  end

  def saml_spec_settings
    settings = saml_settings.dup
    settings.issuer = 'http://localhost:3000'
    settings
  end

  def invalid_authn_context_settings
    settings = saml_settings.dup
    settings.authn_context = 'http://idmanagement.gov/ns/assurance/loa/5'
    settings
  end

  def invalid_service_provider_settings
    settings = saml_settings.dup
    settings.issuer = 'invalid_provider'
    settings
  end

  def invalid_service_provider_and_authn_context_settings
    settings = saml_settings.dup
    settings.authn_context = 'http://idmanagement.gov/ns/assurance/loa/5'
    settings.issuer = 'invalid_provider'
    settings
  end

  def sp1_saml_settings
    settings = saml_settings.dup
    settings.issuer = 'https://rp1.serviceprovider.com/auth/saml/metadata'
    settings
  end

  def sp2_saml_settings
    settings = saml_settings.dup
    settings.issuer = 'https://rp2.serviceprovider.com/auth/saml/metadata'
    settings
  end

  def email_nameid_saml_settings_for_allowed_issuer
    settings = saml_settings.dup
    settings.name_identifier_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
    settings.issuer = 'https://rp1.serviceprovider.com/auth/saml/metadata'
    settings
  end

  def email_nameid_saml_settings_for_disallowed_issuer
    settings = saml_settings.dup
    settings.name_identifier_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
    settings
  end

  def loa3_saml_settings
    settings = sp1_saml_settings.dup
    settings.authn_context = Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
    settings
  end

  def loa3_with_bundle_saml_settings
    settings = loa3_saml_settings
    settings.authn_context = [
      settings.authn_context,
      "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
      "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
    ]
    settings
  end

  def loa1_with_bundle_saml_settings
    settings = sp1_saml_settings
    settings.authn_context = [
      settings.authn_context,
      "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
      "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
    ]
    settings
  end

  def sp1_authnrequest
    auth_request.create(sp1_saml_settings)
  end

  def sp2_authnrequest
    auth_request.create(sp2_saml_settings)
  end

  def loa3_authnrequest
    auth_request.create(loa3_saml_settings)
  end

  def missing_authn_context_saml_settings
    settings = saml_settings.dup
    settings.authn_context = nil
    settings
  end

  def saml_test_key
    @saml_test_key ||= File.read(Rails.root.join('keys', 'saml_test_sp.key'))
  end

  # generates a SAML response and returns a parsed Nokogiri XML document
  def generate_saml_response(user, settings = saml_settings)
    # user needs to be signed in in order to generate an assertion
    sign_in(user)
    saml_get_auth(settings)
  end

  def saml_get_auth(settings)
    # GET redirect binding Authn Request
    get :auth, params: { SAMLRequest: URI.decode(saml_request(settings)) }
  end

  private

  def saml_request(settings)
    authn_request(settings).split('SAMLRequest=').last
  end

  # generate a SAML Authn request
  def authn_request(settings = saml_settings, params = {})
    OneLogin::RubySaml::Authrequest.new.create(settings, params)
  end
end
