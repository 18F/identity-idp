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

  describe '.build_saml_certs_by_year' do
    it 'returns a map with keys based on SAML_YEARS and String values' do
      saml_certs_by_year = described_class.build_saml_certs_by_year
      expect(saml_certs_by_year.keys.sort).to eq(described_class::SAML_YEARS.sort)
      expect(saml_certs_by_year.values).to all be_a(String)
    end

    it 'raises exception if the certificate for a year does not exist' do
      stub_const('SamlEndpoint::SAML_YEARS', ['2000'])
      expect { described_class.build_saml_certs_by_year }.to raise_error(
        RuntimeError,
        'No SAML certificate for suffix 2000',
      )
    end

    it 'raises exception if the certificate value is invalid' do
      cert_year = SamlEndpoint::SAML_YEARS.first
      stub_const('SamlEndpoint::SAML_YEARS', [cert_year])
      allow(AppArtifacts.store).to(receive(:[])).with("saml_#{cert_year}_cert").and_return(
        'bad cert',
      )

      expect { described_class.build_saml_certs_by_year }.to raise_error(
        RuntimeError,
        "SAML certificate for #{cert_year} is invalid",
      )
    end
  end

  describe '.build_saml_keys_by_year' do
    it 'returns a map with keys based on SAML_YEARS and String values' do
      saml_keys_by_year = described_class.build_saml_keys_by_year
      expect(saml_keys_by_year.keys.sort).to eq(described_class::SAML_YEARS.sort)
      expect(saml_keys_by_year.values).to all be_a(OpenSSL::PKey::RSA)
    end

    it 'raises exception if the key for a year does not exist' do
      stub_const('SamlEndpoint::SAML_YEARS', ['2000'])
      expect { described_class.build_saml_keys_by_year }.to raise_error(
        RuntimeError,
        'No SAML private key for suffix 2000',
      )
    end

    it 'raises exception if the key value is invalid' do
      key_year = SamlEndpoint::SAML_YEARS.first
      stub_const('SamlEndpoint::SAML_YEARS', [key_year])
      allow(AppArtifacts.store).to(receive(:[])).with("saml_#{key_year}_key").and_return(
        'bad key',
      )

      expect { described_class.build_saml_keys_by_year }.to raise_error(
        RuntimeError,
        "SAML key or passphrase for #{key_year} is invalid",
      )
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
