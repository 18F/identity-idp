require 'saml_idp_constants'

## GET /api/saml/auth helper methods
module SamlAuthHelper
  def saml_settings
    settings = OneLogin::RubySaml::Settings.new

    # SP settings
    settings.assertion_consumer_service_url = 'http://localhost:3000/test/saml/decode_assertion'
    settings.assertion_consumer_logout_service_url = 'http://localhost:3000/test/saml/decode_slo_request'
    settings.certificate = saml_cert
    settings.private_key = private_key
    settings.authn_context = Saml::Idp::Constants::LOA1_AUTHNCONTEXT_CLASSREF

    # SP + IdP Settings
    settings.issuer = 'http://test.host'
    settings.security[:authn_requests_signed] = true
    settings.security[:logout_requests_signed] = true
    settings.security[:embed_sign] = true
    settings.security[:digest_method] = 'http://www.w3.org/2001/04/xmlenc#sha256'
    settings.security[:signature_method] = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
    settings.name_identifier_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
    settings.double_quote_xml_attribute_values = true
    # IdP setting
    settings.idp_sso_target_url = 'http://www.example.com/api/saml/auth'
    settings.idp_slo_target_url = 'http://www.example.com/api/saml/logout'
    settings.idp_cert_fingerprint = fingerprint

    settings
  end

  def private_key
    @private_key ||= OpenSSL::PKey::RSA.new(
      File.read(Rails.root + 'keys/saml.key.enc'),
      Figaro.env.saml_passphrase
    ).to_pem
  end

  def fingerprint
    'F9:A3:9B:2F:8F:1C:E2:79:27:69:EB:32:ED:2A:D5:' \
    'A2:A7:58:5F:C0:74:8A:4A:03:D9:0F:77:A5:89:7F:F9:68'
  end

  def saml_cert
    @saml_cert ||= File.read("#{Rails.root}/certs/saml_cert.crt")
  end

  # generates a SAML response and returns a parsed Nokogiri XML document
  def generate_saml_response(options = {})
    # set default options
    options.reverse_merge! ial_token: false
    # user needs to be signed in in order to generate an assertion
    sign_in(user)

    begin
      send_get_request(options)
    rescue XMLSec::SigningError
      skip 'Broken on OSX. Use Vagrant to test.'
    end
  end

  def decrypted_saml_response
    @decrypted_response ||= generate_saml_response
  end

  def issuer
    decrypted_saml_response.at(
      '//response:Response/ds:Issuer',
      ds: Saml::XML::Namespaces::ASSERTION,
      response: Saml::XML::Namespaces::PROTOCOL
    )
  end

  def status
    decrypted_saml_response.at('//ds:Status', ds: Saml::XML::Namespaces::PROTOCOL)
  end

  def status_code
    decrypted_saml_response.at('//ds:StatusCode', ds: Saml::XML::Namespaces::PROTOCOL)
  end

  def transform(algorithm)
    decrypted_saml_response.at(
      "//ds:Transform[@Algorithm='#{algorithm}']",
      ds: Saml::XML::Namespaces::SIGNATURE
    )
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

  def invalid_saml_settings
    settings = saml_settings.dup
    settings.authn_context = 'http://idmanagement.gov/ns/assurance/loa/2'
    settings
  end

  def invalid_authnrequest_get
    auth_request.create(invalid_saml_settings)
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

  def sp1_authnrequest
    auth_request.create(sp1_saml_settings)
  end

  def sp2_authnrequest
    auth_request.create(sp2_saml_settings)
  end

  def missing_auth_context_saml_settings
    settings = saml_settings.dup
    settings.authn_context = nil
    settings
  end

  def authnrequest_get_with_missing_authn_context
    auth_request.create(missing_auth_context_saml_settings)
  end

  # generate a SAML Authn request
  def authn_request(settings = saml_settings, params = {})
    OneLogin::RubySaml::Authrequest.new.create(
      settings,
      params,
      key: key,
      algorithm: :sha256
    )
  end

  def saml_request
    authn_request.split('SAMLRequest=').last
  end

  def saml_test_key
    @saml_test_key ||= File.read("#{Rails.root}/keys/saml_test.key.enc")
  end

  def create_new_account(options = { reset_session: false })
    email = Faker::Internet.safe_email
    sign_up_with_and_set_password_for(email, options[:reset_session])
    email
  end

  private

  def send_get_request(_options)
    saml_get_auth
  end

  def saml_get_auth
    # GET redirect binding Authn Request
    get(:auth, SAMLRequest: URI.decode(saml_request))
    # decrypt xml using XMLSecMeHarder (via Nokogiri)
    decrypted_doc = Nokogiri::XML(saml_response).decrypt!(key: saml_test_key).to_s
    # parse decrypted XML to clean blanks
    Nokogiri::XML(decrypted_doc, &:noblanks)
  end

  def saml_response
    Base64.decode64(
      OneLogin::RubySaml::Response.new(
        Nokogiri::HTML(response.body).at_css('#SAMLResponse')['value'],
        private_key: key,
        private_key_password: '').response
    )
  end

  def authenticate_user(user = create(:user, :signed_up))
    sign_in_user(user)
    fill_in 'code', with: user.otp_code
    click_button 'Submit'
  rescue XMLSec::SigningError
    skip 'Broken on OSX. Use pre-built VM to test.'
  end
end
