require_relative '../../lib/app_artifacts'

AppArtifacts.setup do |config|
  config.add_artifact(:saml_2019_cert, '/%<env>s/saml2019.crt')
  config.add_artifact(:saml_2019_key, '/%<env>s/saml2019.key.enc')
  config.add_artifact(:saml_2020_cert, '/%<env>s/saml2020.crt')
  config.add_artifact(:saml_2020_key, '/%<env>s/saml2020.key.enc')
  config.add_artifact(:saml_2021_cert, '/%<env>s/saml2021.crt')
  config.add_artifact(:saml_2021_key, '/%<env>s/saml2021.key.enc')
end
