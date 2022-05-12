require 'feature_management'

SamlIdp.configure do |config|
  protocol = Rails.env.development? ? 'http://' : 'https://'
  api_base = protocol + IdentityConfig.store.domain_name + '/api'

  config.algorithm = OpenSSL::Digest::SHA256
  # config.signature_alg = 'rsa-sha256'
  # config.digest_alg = 'sha256'

  # Disabled because authnrequest signing doesn't prevent any
  # attack that can be thought of.
  # config.verify_authnrequest_sig = true

  # Organization contact information
  config.organization_name = 'login.gov'
  config.organization_url = 'https://login.gov'
  config.base_saml_location = "#{api_base}/saml"
  config.attribute_service_location = "#{api_base}/saml/attributes"
  config.single_service_post_location = "#{api_base}/saml/auth"
  config.single_logout_service_post_location = "#{api_base}/saml/logout"
  config.remote_logout_service_post_location = "#{api_base}/saml/remotelogout"

  # Name ID
  config.name_id.formats =
    {
      persistent: ->(principal) { principal.asserted_attributes[:uuid][:getter].call(principal) },
      email_address: ->(principal) { EmailContext.new(principal).last_sign_in_email_address.email },
    }

  ## Technical contact ##
  # config.technical_contact.company = "Example"
  # config.technical_contact.given_name = "Jonny"
  # config.technical_contact.sur_name = "Support"
  # config.technical_contact.telephone = "55555555555"
  # config.technical_contact.email_address = "example@example.com"

  # Find ServiceProvider metadata_url and fingerprint based on our settings
  config.service_provider.finder = lambda do |issuer_or_entity_id|
    ServiceProvider.find_by(issuer: issuer_or_entity_id)&.metadata || {}
  end
end
