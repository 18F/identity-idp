require 'rails_helper'

describe SamlEndpoint do
  before do
    allow(FeatureManagement).to receive(:use_cloudhsm?).and_return(true)
  end

  let(:path) { '/api/saml/auth2018' }
  let(:request) do
    request_double = double
    allow(request_double).to receive(:path).and_return(path)
    request_double
  end

  subject { described_class.new(request) }

  describe '.suffixes' do
    it 'should list the suffixes that are configured' do
      result = described_class.suffixes

      expect(result).to eq(['', '2018', 'cloudhsm'])
    end
  end

  describe 'endpoint_configs' do
    it 'should return an array of parsed endpoint config data' do
      result = described_class.endpoint_configs

      expect(result).to eq(
        [
          { suffix: '', secret_key_passphrase: 'trust-but-verify' },
          { suffix: '2018', secret_key_passphrase: 'asdf1234' },
          { suffix: 'cloudhsm', cloudhsm_key_label: 'key1' },
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
          File.read('keys/saml2018.key.enc'),
          'asdf1234',
        ).to_pem,
      )
    end

    context 'when the key file does not exist' do
      let(:path) { '/saml/auth_dne' }

      before do
        allow(SamlEndpoint).to receive(:endpoint_configs).and_return(
          [
            { suffix: '_dne', secret_key_passphrase: 'asdf1234' },
          ],
        )
      end

      it 'raises an error' do
        expect { subject.secret_key }.to raise_error(
          "No private key at path #{Rails.root.join('keys', 'saml_dne.key.enc')}",
        )
      end
    end

    context 'with a cloudhsm key' do
      let(:path) { '/api/saml/authcloudhsm' }

      it 'returns nil' do
        expect(subject.secret_key).to eq(nil)
      end
    end
  end

  describe '#cloudhsm_key_label' do
    context 'with a cloudhsm key label' do
      let(:path) { '/api/saml/authcloudhsm' }

      it 'returns the cloudhsm key label' do
        expect(subject.cloudhsm_key_label).to eq('key1')
      end
    end

    context 'with a local key' do
      let(:path) { '/api/saml/auth2018' }

      it 'returns nil' do
        expect(subject.cloudhsm_key_label).to eq(nil)
      end
    end

    context 'when cloudhsm is disabled' do
      let(:path) { '/api/saml/authcloudhsm' }

      before do
        allow(FeatureManagement).to receive(:use_cloudhsm?).and_return(false)
      end

      it 'returns nil' do
        expect(subject.cloudhsm_key_label).to eq(nil)
      end
    end
  end

  describe '#x509_certificate' do
    it 'returns the x509 cert loaded from the filesystem' do
      expect(
        subject.x509_certificate,
      ).to eq(
        File.read('certs/saml2018.crt.example'),
      )
    end
  end

  describe '#saml_metadata' do
    it 'returns the saml metadata with the suffix added to the urls' do
      result = subject.saml_metadata

      expect(result.configurator.single_service_post_location).to match(%r{api\/saml\/auth2018\Z})
      expect(result.configurator.single_logout_service_post_location).to match(
        %r{api\/saml\/logout2018\Z},
      )
    end
  end
end
