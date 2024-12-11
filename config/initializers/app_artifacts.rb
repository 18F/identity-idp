# frozen_string_literal: true

require 'app_artifacts'
require 'openid_connect_key_validation'

AppArtifacts.setup do |store|
  # When adding or removing certs, make sure to update the 'saml_endpoint_configs' config
  store.add_artifact(:saml_2023_cert, '/%<env>s/saml2023.crt')
  store.add_artifact(:saml_2023_key, '/%<env>s/saml2023.key.enc')
  store.add_artifact(:saml_2024_cert, '/%<env>s/saml2024.crt')
  store.add_artifact(:saml_2024_key, '/%<env>s/saml2024.key.enc')

  store.add_artifact(:oidc_primary_private_key, '/%<env>s/oidc.key') do |k|
    OpenSSL::PKey::RSA.new(k)
  end
  store.add_artifact(:oidc_primary_public_key, '/%<env>s/oidc.pub') do |k|
    OpenSSL::PKey::RSA.new(k)
  end
  store.add_artifact(
    :oidc_secondary_private_key, '/%<env>s/oidc_secondary.key',
    allow_missing: true
  ) do |k|
    OpenSSL::PKey::RSA.new(k)
  end
  store.add_artifact(
    :oidc_secondary_public_key, '/%<env>s/oidc_secondary.pub',
    allow_missing: true
  ) do |k|
    OpenSSL::PKey::RSA.new(k)
  end
end

primary_valid = OpenidConnectKeyValidation.valid?(
  public_key: AppArtifacts.store.oidc_primary_public_key,
  private_key: AppArtifacts.store.oidc_primary_private_key,
)
raise 'OIDC Primary Public/Private Keys do not match' if !primary_valid

secondary_valid =
  (AppArtifacts.store.oidc_secondary_private_key.nil? &&
   AppArtifacts.store.oidc_secondary_public_key.nil?) ||
  OpenidConnectKeyValidation.valid?(
    public_key: AppArtifacts.store.oidc_secondary_public_key,
    private_key: AppArtifacts.store.oidc_secondary_private_key,
  )
raise 'OIDC Secondary Public/Private Keys are invalid' if !secondary_valid
