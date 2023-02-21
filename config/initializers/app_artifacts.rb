require 'app_artifacts'

AppArtifacts.setup do |store|
  years = IdentityConfig.store.saml_endpoint_configs.map { |s| s[:suffix].to_i }

  years.each do |year|
    store.add_artifact(:"saml_{year}_cert", "/%<env>s/saml#{year}.crt")
    store.add_artifact(:"saml_{year}_key", '/%<env>s/saml{year}.key.enc')
  end

  store.add_artifact(:oidc_private_key, '/%<env>s/oidc.key') { |k| OpenSSL::PKey::RSA.new(k) }
  store.add_artifact(:oidc_public_key, '/%<env>s/oidc.pub') { |k| OpenSSL::PKey::RSA.new(k) }
end
