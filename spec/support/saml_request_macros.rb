require 'saml_idp/logout_request_builder'

module SamlRequestMacros

  def make_saml_request(requested_saml_acs_url = "https://foo.example.com/saml/consume")
    auth_request = OneLogin::RubySaml::Authrequest.new
    auth_url = auth_request.create(saml_settings(requested_saml_acs_url))
    CGI.unescape(auth_url.split("=").last)
  end

  def make_saml_logout_request(requested_saml_logout_url = 'https://foo.example.com/saml/logout')
    request_builder = SamlIdp::LogoutRequestBuilder.new(
      'some_response_id',
      'http://example.com',
      requested_saml_logout_url,
      'some_name_id',
      OpenSSL::Digest::SHA256
    )
    request_builder.encoded
  end

  def saml_settings(saml_acs_url = "https://foo.example.com/saml/consume")
    settings = OneLogin::RubySaml::Settings.new
    settings.assertion_consumer_service_url = saml_acs_url
    settings.issuer = "http://example.com/issuer"
    settings.idp_sso_target_url = "http://idp.com/saml/idp"
    settings.idp_cert_fingerprint = SamlIdp::Default::FINGERPRINT
    settings.name_identifier_format = SamlIdp::Default::NAME_ID_FORMAT
    settings
  end

  def print_pretty_xml(xml_string)
    doc = REXML::Document.new xml_string
    outbuf = ""
    doc.write(outbuf, 1)
    puts outbuf
  end
end
