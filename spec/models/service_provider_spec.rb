require 'rails_helper'

describe ServiceProvider do
  let(:service_provider) { ServiceProvider.from_issuer('http://localhost:3000') }

  describe 'validations' do
    it 'validates that all redirect_uris are absolute, parsable uris' do
      valid_sp = build(:service_provider, redirect_uris: ['http://foo.com'])
      missing_protocol_sp = build(:service_provider, redirect_uris: ['foo.com'])
      empty_uri_sp = build(:service_provider, redirect_uris: [''])
      relative_uri_sp = build(:service_provider, redirect_uris: ['/asdf/hjkl'])
      bad_uri_sp = build(:service_provider, redirect_uris: [' http://foo.com'])
      missing_host_sp = build(:service_provider, redirect_uris: ['hipchat://'])
      hipchat_sp = build(:service_provider, redirect_uris: ['hipchat://return'])

      expect(valid_sp).to be_valid
      expect(missing_protocol_sp).to_not be_valid
      expect(empty_uri_sp).to_not be_valid
      expect(relative_uri_sp).to_not be_valid
      expect(bad_uri_sp).to_not be_valid
      expect(missing_host_sp).to_not be_valid
      expect(hipchat_sp).to be_valid
    end

    it 'allows redirect_uris to be blank' do
      sp = build(:service_provider, redirect_uris: nil)
      expect(sp).to be_valid
    end
  end

  describe '#issuer' do
    it 'returns the constructor value' do
      expect(service_provider.issuer).to eq 'http://localhost:3000'
    end
  end

  describe '#from_issuer' do
    context 'the record exists' do
      it 'fetches the record' do
        expect(service_provider).to be_a ServiceProvider
        expect(service_provider.persisted?).to eq true
      end
    end

    context 'the record does not exist' do
      let(:service_provider) { ServiceProvider.from_issuer('no-such-issuer') }

      it 'returns NullServiceProvider' do
        expect(service_provider).to be_a NullServiceProvider
      end
    end
  end

  describe '#metadata' do
    context 'when the service provider is defined in the YAML' do
      it 'returns a hash with symbolized attributes from YAML plus fingerprint' do
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

  describe 'piv_cac_available?' do
    context 'when the service provider is with an enabled agency' do
      it 'is truthy' do
        allow(PivCacService).to receive(:piv_cac_available_for_agency?).and_return(true)
        expect(service_provider.piv_cac_available?).to be_truthy
      end
    end

    context 'when the service provider agency is not enabled' do
      it 'is falsey' do
        allow(PivCacService).to receive(:piv_cac_available_for_agency?).and_return(false)

        expect(service_provider.piv_cac_available?).to be_falsey
      end
    end

    context 'when the service provider setting depends on the user email' do
      let(:user) { create(:user) }

      it 'calls with the user email' do
        expect(PivCacService).to receive(
          :piv_cac_available_for_agency?
        ).with(service_provider.agency, user.email)

        service_provider.piv_cac_available?(user)
      end
    end
  end

  describe '#encryption_opts' do
    context 'when responses are not encrypted' do
      it 'returns nil' do
        # block_encryption is set to 'none' for this SP
        expect(service_provider.encryption_opts).to be_nil
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
        expect(service_provider.approved?).to be true
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
        service_provider.update(active: false)

        expect(service_provider.live?).to be false
      end
    end

    context 'when the service provider is active and approved' do
      it 'returns true' do
        expect(service_provider.live?).to be true
      end
    end

    context 'when the service provider is active but not approved' do
      it 'returns false' do
        service_provider.update(approved: false)

        expect(service_provider.live?).to be false
      end
    end
  end

  describe '#ssl_cert' do
    it 'returns the remote setting cert' do
      WebMock.allow_net_connect!
      sp = create(:service_provider, issuer: 'foo', cert: 'https://raw.githubusercontent.com/18F/identity-idp/master/certs/sp/saml_test_sp.crt')
      expect(sp.ssl_cert.class).to be(OpenSSL::X509::Certificate)
    end

    it 'returns the local cert' do
      sp = create(:service_provider, issuer: 'foo', cert: 'saml_test_sp')
      expect(sp.ssl_cert.class).to be(OpenSSL::X509::Certificate)
    end
  end
end
