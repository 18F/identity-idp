require 'rails_helper'

describe ServiceProvider do
  describe '#issuer' do
    it 'returns the constructor value' do
      sp = ServiceProvider.from_issuer('http://localhost:3000')
      expect(sp.issuer).to eq 'http://localhost:3000'
    end
  end

  describe '#from_issuer' do
    context 'the record exists' do
      it 'fetches the record' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')

        expect(sp).to be_a ServiceProvider
        expect(sp.persisted?).to eq true
      end
    end

    context 'the record does not exist' do
      it 'returns NullServiceProvider' do
        sp = ServiceProvider.from_issuer('no-such-issuer')

        expect(sp).to be_a NullServiceProvider
      end
    end
  end

  describe '#metadata' do
    context 'when the service provider is defined in the YAML' do
      it 'returns a hash with symbolized attributes from YAML plus fingerprint' do
        service_provider = ServiceProvider.from_issuer('http://localhost:3000')

        fingerprint = {
          fingerprint: '40808e52ef80f92e697149e058af95f898cefd9a54d0dc2416bd607c8f9891fa',
        }

        yaml_attributes = ServiceProviderConfig.new(
          issuer: 'http://localhost:3000'
        ).sp_attributes

        expect(service_provider.metadata).to eq yaml_attributes.merge!(fingerprint)
      end
    end
  end

  describe '#encryption_opts' do
    context 'when responses are not encrypted' do
      it 'returns nil' do
        # block_encryption is set to 'none' for this SP
        sp = ServiceProvider.from_issuer('http://localhost:3000')

        expect(sp.encryption_opts).to be_nil
      end
    end

    context 'when responses are encrypted' do
      it 'returns a hash with cert, block_encryption, and key_transport keys' do
        # block_encryption is 'aes256-cbc' for this SP
        sp = ServiceProvider.from_issuer('https://rp1.serviceprovider.com/auth/saml/metadata')

        expect(sp.encryption_opts.keys).to eq %i[cert block_encryption key_transport]
        expect(sp.encryption_opts[:block_encryption]).to eq 'aes256-cbc'
        expect(sp.encryption_opts[:key_transport]).to eq 'rsa-oaep-mgf1p'
        expect(sp.encryption_opts[:cert]).to be_an_instance_of(OpenSSL::X509::Certificate)
      end

      it 'calls OpenSSL::X509::Certificate with the SP cert' do
        sp = ServiceProvider.from_issuer('https://rp1.serviceprovider.com/auth/saml/metadata')
        cert = File.read(Rails.root.join('certs', 'sp', 'saml_test_sp.crt'))

        expect(OpenSSL::X509::Certificate).to receive(:new).with(cert)

        sp.encryption_opts
      end
    end
  end

  describe '#approved?' do
    context 'when the service provider is not included in the list of authorized providers' do
      it 'returns false' do
        sp = create(:service_provider, issuer: 'foo')

        expect(sp.approved?).to be false
      end
    end

    context 'when the service provider is included in the list of authorized providers' do
      it 'returns true' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')

        expect(sp.approved?).to be true
      end
    end
  end

  describe '#live?' do
    context 'when the service provider is not approved' do
      it 'returns false' do
        sp = create(:service_provider, issuer: 'foo')

        expect(sp.live?).to be false
      end
    end

    context 'when the service provider is approved but not active' do
      it 'returns false' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        sp.update(active: false)

        expect(sp.live?).to be false
      end
    end

    context 'when the service provider is active and approved' do
      it 'returns true' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')

        expect(sp.live?).to be true
      end
    end

    context 'when the service provider is active but not approved' do
      it 'returns false' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        sp.update(approved: false)

        expect(sp.live?).to be false
      end
    end
  end
end
