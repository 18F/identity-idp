require 'app_artifacts'

AppArtifacts.setup do |store|
  # When adding or removing certs, make sure to update the 'saml_endpoint_configs' config
  store.add_artifact(:saml_2023_cert, '/%<env>s/saml2023.crt')
  store.add_artifact(:saml_2023_key, '/%<env>s/saml2023.key.enc')

  store.add_artifact(:oidc_private_key, '/%<env>s/oidc.key') { |k| OpenSSL::PKey::RSA.new(k) }
  store.add_artifact(:oidc_public_key, '/%<env>s/oidc.pub') { |k| OpenSSL::PKey::RSA.new(k) }
end
