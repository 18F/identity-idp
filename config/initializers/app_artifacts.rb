# frozen_string_literal: true

require 'app_artifacts'
require 'openid_connect_key_validation'

AppArtifacts.setup do |store|
  # When adding or removing certs, make sure to update the 'saml_endpoint_configs' config
  store.add_artifact(:saml_2023_cert, '/%<env>s/saml2023.crt')
  store.add_artifact(:saml_2023_key, '/%<env>s/saml2023.key.enc')
  store.add_artifact(:saml_2024_cert, '/%<env>s/saml2024.crt')
  store.add_artifact(:saml_2024_key, '/%<env>s/saml2024.key.enc')

  store.add_artifact(:oidc_private_key, '/%<env>s/oidc.key') { |k| OpenSSL::PKey::RSA.new(k) }
  store.add_artifact(:oidc_public_key, '/%<env>s/oidc.pub') { |k| OpenSSL::PKey::RSA.new(k) }
end

valid = OpenidConnectKeyValidation.valid?(
  public_key: AppArtifacts.store.oidc_public_key,
  private_key: AppArtifacts.store.oidc_private_key,
)
raise 'OIDC Public/Private Keys do not match' if !valid
