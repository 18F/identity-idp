require 'rails_helper'

describe ServiceProviderConfig do
  describe '#sp_attributes' do
    it 'returns the issuer attributes for the Rails.env entry in the YAML file' do
      config = ServiceProviderConfig.new(issuer: 'http://test.host')

      yaml_hash = {
        acs_url: 'http://test.host/test/saml/decode_assertion',
        block_encryption: 'aes256-cbc',
        metadata_url: 'http://test.host/test/saml/metadata',
        sp_initiated_login_url: 'http://test.host/test/saml',
      }

      expect(config.sp_attributes).to include yaml_hash
    end
  end
end
