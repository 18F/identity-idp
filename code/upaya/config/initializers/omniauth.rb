# OmniAuth is used to authenticate against Internal ICAM
# and the test SAML IDP within Ferris for authenticating CIS
# employees
require 'feature_management'
require 'omniauth'

DEFAULT_OPTIONS = {
  issuer: "https://#{Figaro.env.domain_name}/users/auth/saml",
  idp_sso_target_url: Figaro.env.internal_icam_url,
  single_signon_service_binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
  idp_cert: Rails.application.secrets.saml_idp_cert,
  name_identifier_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
  allowed_clock_drift: 60.seconds,
  certificate: Rails.application.secrets.saml_cert,
  private_key: OpenSSL::PKey::RSA.new(
    File.read(Rails.root + 'config/saml.key.enc'),
    Figaro.env.saml_passphrase).to_pem,
  assertion_consumer_service_url: "https://#{Figaro.env.domain_name}/users/auth/saml/callback",
  assertion_consumer_service_binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
  authn_context: 'http://idmanagement.gov/ns/assurance/loa/2',
  compress_request: false,
  double_quote_xml_attribute_values: true,
  security: {
    authn_requests_signed: true,
    embed_sign: true,
    digest_method: 'http://www.w3.org/2000/09/xmldsig#sha1',
    signature_method: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
  }
}
options = DEFAULT_OPTIONS

if Rails.env == 'development'
  options = DEFAULT_OPTIONS.merge(
    issuer: "http://#{Figaro.env.domain_name}/users/auth/saml",
    assertion_consumer_service_url: "http://#{Figaro.env.domain_name}/users/auth/saml/callback",
    allowed_clock_drift: 1.hour,
    security: {
      authn_requests_signed: true,
      embed_sign: true,
      digest_method: 'http://www.w3.org/2001/04/xmlenc#sha256',
      signature_method: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
    }
  )
end

if FeatureManagement.allow_ent_icam_auth?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :saml, options
  end
end
