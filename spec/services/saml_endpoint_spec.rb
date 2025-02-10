require 'rails_helper'

RSpec.describe SamlEndpoint do
  let(:year) { '2024' }

  subject { described_class.new(year) }

  describe '.suffixes' do
    it 'should list the suffixes that are configured' do
      result = described_class.suffixes

      expect(result).to eq(%w[2024 2023])
    end
  end

  describe 'endpoint_configs' do
    it 'should return an array of parsed endpoint config data' do
      result = described_class.endpoint_configs

      expect(result).to eq(
        [
          { suffix: '2024', secret_key_passphrase: 'trust-but-verify' },
          {
            # rubocop:disable Layout/LineLength
            comment: 'this extra year is needed to demonstrate how handling multiple live years works in spec/requests/saml_requests_spec.rb',
            # rubocop:enable Layout/LineLength
            secret_key_passphrase: 'trust-but-verify',
            suffix: '2023',
          },
        ],
      )
    end
  end

  describe '#secret_key' do
    it 'returns the key loaded from the file system' do
      expect(
        subject.secret_key.to_pem,
      ).to eq(
        OpenSSL::PKey::RSA.new(
          AppArtifacts.store.saml_2024_key,
          'trust-but-verify',
        ).to_pem,
      )
    end

    context 'when the key file does not exist' do
      let(:year) { '_dne' }

      before do
        allow(SamlEndpoint).to receive(:endpoint_configs).and_return(
          [
            { suffix: '_dne', secret_key_passphrase: 'asdf1234' },
          ],
        )
      end

      it 'raises an error' do
        expect { subject.secret_key }.to raise_error(
          'No SAML private key for suffix _dne',
        )
      end
    end
  end

  describe '#x509_certificate' do
    it 'returns the x509 cert loaded from the filesystem' do
      expect(
        subject.x509_certificate,
      ).to eq(
        AppArtifacts.store.saml_2024_cert,
      )
    end
  end

  describe '#saml_metadata' do
    it 'returns the saml metadata with the suffix added to the urls' do
      result = subject.saml_metadata

      expect(result.configurator.single_service_post_location).to match(%r{api/saml/auth2024\Z})
    end
  end
end
