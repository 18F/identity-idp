module SamlRequestMacros

  def make_saml_request(requested_saml_acs_url = "https://foo.example.com/saml/consume")
    auth_request = Onelogin::Saml::Authrequest.new
    auth_url = auth_request.create(saml_settings(requested_saml_acs_url))
    CGI.unescape(auth_url.split("=").last)
  end

  def saml_settings(saml_acs_url = "https://foo.example.com/saml/consume")
    settings = Onelogin::Saml::Settings.new
    settings.assertion_consumer_service_url = saml_acs_url
    settings.issuer = "http://example.com/issuer"
    settings.idp_sso_target_url = "http://idp.com/saml/idp"
    settings.idp_cert_fingerprint = SamlIdp::Default::FINGERPRINT
    settings.name_identifier_format = SamlIdp::Default::NAME_ID_FORMAT
    settings
  end

end