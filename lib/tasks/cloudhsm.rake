namespace :cloudhsm do
  desc 'Generate a new saml key'
  task generate_saml_key: :environment do
    CloudhsmKeyGenerator.new.generate_saml_key
  end
end
