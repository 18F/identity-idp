# In prod this script will run on a RamDisk

namespace :cloudhsm do
  desc 'Generate a new saml key and grant idp access to the key'
  task generate_saml_key: :environment do
    saml_key_label, _handle = CloudhsmKeyGenerator.new.generate_saml_key
    CloudhsmKeySharer.new(saml_key_label).share_saml_key
  end
end
