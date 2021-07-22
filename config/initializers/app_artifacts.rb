require 'app_artifacts'

AppArtifacts.setup do |store|
  store.add_artifact(:saml_2021_cert, '/%<env>s/saml2021.crt')
  store.add_artifact(:saml_2021_key, '/%<env>s/saml2021.key.enc')

  store.add_artifact(:oidc_private_key, '/%<env>s/oidc.key') { |k| OpenSSL::PKey::RSA.new(k) }
  store.add_artifact(:oidc_public_key, '/%<env>s/oidc.pub') { |k| OpenSSL::PKey::RSA.new(k) }
end
