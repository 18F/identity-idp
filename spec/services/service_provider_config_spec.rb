require 'rails_helper'

describe ServiceProviderConfig do
  describe '#sp_attributes' do
    context 'when the domain_name is superb.legit.domain.gov' do
      it 'returns the issuer attributes for the superb.legit.domain.gov entry in the YAML file' do
        allow(Figaro.env).to receive(:domain_name).and_return('superb.legit.domain.gov')

        config = ServiceProviderConfig.new(
          filename: 'service_providers.yml', issuer: 'urn:govheroku:serviceprovider'
        )

        yaml_hash = {
          acs_url: 'https://vets.gov/users/auth/saml/callback',
          assertion_consumer_logout_service_url: 'https://vets.gov/api/saml/logout',
          block_encryption: 'aes256-cbc',
          cert: 'saml_test_sp',
          agency: 'test_agency',
          attribute_bundle: %w(email phone)
        }

        expect(config.sp_attributes).to eq yaml_hash
      end
    end

    context 'when the domain_name is not superb.legit.domain.gov' do
      it 'returns the issuer attributes for the Rails.env entry in the YAML file' do
        config = ServiceProviderConfig.new(
          filename: 'service_providers.yml', issuer: 'http://test.host'
        )

        yaml_hash = {
          acs_url: 'http://test.host/test/saml/decode_assertion',
          block_encryption: 'aes256-cbc',
          metadata_url: 'http://test.host/test/saml/metadata',
          sp_initiated_login_url: 'http://test.host/test/saml'
        }

        expect(config.sp_attributes).to eq yaml_hash
      end
    end
  end
end
