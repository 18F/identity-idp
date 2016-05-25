require 'service_provider'

SamlIdp.configure do |config|
  protocol = Rails.env.development? ? 'http://' : 'https://'
  api_base = protocol + Figaro.env.domain_name + '/api'

  config.x509_certificate = File.read("#{Rails.root}/certs/saml_cert.crt")
  config.secret_key = OpenSSL::PKey::RSA.new(
    File.read(Rails.root + 'keys/saml.key.enc'),
    Figaro.env.saml_passphrase).to_pem

  config.algorithm = OpenSSL::Digest::SHA256
  # config.signature_alg = 'rsa-sha256'
  # config.digest_alg = 'sha256'

  # Disabled because authnrequest signing doesn't prevent any
  # attack that can be thought of.
  # config.verify_authnrequest_sig = true

  # Organization contact information
  config.organization_name = '18F'
  config.organization_url = 'http://18f.gsa.gov'
  config.base_saml_location = "#{api_base}/saml"
  config.attribute_service_location = "#{api_base}/saml/attributes"
  config.single_service_post_location = "#{api_base}/saml/auth"
  config.single_logout_service_post_location = "#{api_base}/saml/logout"

  # Name ID
  config.name_id.formats =
    {
      persistent: -> (principal) { principal.uuid },
      email_address: -> (principal) { principal.email }
    }

  # Attributes
  config.attributes = {
    uuid: {
      getter: :uuid,
      name_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT,
      name_id_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT
    },
    email: {
      getter: :email,
      name_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
      name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS
    },
    mobile: { getter: :mobile }
  }

  ## Technical contact ##
  # config.technical_contact.company = "Example"
  # config.technical_contact.given_name = "Jonny"
  # config.technical_contact.sur_name = "Support"
  # config.technical_contact.telephone = "55555555555"
  # config.technical_contact.email_address = "example@example.com"

  # Find ServiceProvider metadata_url and fingerprint based on our settings
  config.service_provider.finder = lambda do |issuer_or_entity_id|
    ServiceProvider.new(issuer_or_entity_id).metadata
  end
end
