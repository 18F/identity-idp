require 'rails_helper'

RSpec.describe SamlEndpoint do
  let(:year) { '2025' }

  subject { described_class.new(year) }

  describe '.suffixes' do
    it 'should list the suffixes that are configured' do
      result = described_class.suffixes

      expect(result).to eq(%w[2024 2025])
    end
  end

  describe '#secret_key' do
    it 'returns the key loaded from the file system' do
      expect(
        subject.secret_key.to_pem,
      ).to eq(
        OpenSSL::PKey::RSA.new(
          AppArtifacts.store.saml_2025_key,
          'trust-but-verify',
        ).to_pem,
      )
    end

    context 'when the key file does not exist' do
      let(:year) { '_dne' }

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
        AppArtifacts.store.saml_2025_cert,
      )
    end
  end

  describe '#saml_metadata' do
    it 'returns the saml metadata with the suffix added to the urls' do
      result = subject.saml_metadata

      expect(result.configurator.single_service_post_location).to match(%r{api/saml/auth2025\Z})
    end
  end
end
