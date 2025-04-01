require 'rails_helper'

RSpec.describe ServiceProvider do
  let(:service_provider) { ServiceProvider.find_by(issuer: 'http://localhost:3000') }

  describe 'associations' do
    subject { service_provider }

    it { is_expected.to belong_to(:agency) }

    it do
      is_expected.to have_many(:identities)
        .inverse_of(:service_provider_record)
        .with_foreign_key('service_provider')
        .with_primary_key('issuer')
    end
  end

  describe 'scopes' do
    before do
      clear_agreements_data
      Agency.destroy_all
      ServiceProvider.destroy_all
    end

    let!(:external_sps) do
      [
        create(:service_provider, :external),
        create(:service_provider, iaa: nil),
      ]
    end
    let!(:internal_sp) { create(:service_provider, :internal) }

    describe '.internal' do
      it 'includes apps with iaa: LGINTERNAL' do
        expect(ServiceProvider.internal.to_a).to eq([internal_sp])
      end
    end

    describe '.external' do
      it 'includes apps without iaa: LGINTERNAL' do
        expect(ServiceProvider.external.to_a).to match_array(external_sps)
      end
    end
  end

  describe '#issuer' do
    it 'returns the constructor value' do
      expect(service_provider.issuer).to eq 'http://localhost:3000'
    end
  end

  describe '#metadata' do
    context 'when the service provider is defined in the YAML' do
      it 'returns a hash with symbolized attributes from YAML' do
        yaml_attributes = {
          issuer: 'http://localhost:3000',
        }

        expect(service_provider.metadata).to include(yaml_attributes)
      end
    end
  end

  describe '#skip_encryption_allowed' do
    context 'SP in allowed list' do
      before do
        allow(IdentityConfig.store).to receive(:skip_encryption_allowed_list)
          .and_return(['http://localhost:3000'])
      end

      it 'allows the SP to optionally skip encrypting the SAML response' do
        expect(service_provider.skip_encryption_allowed).to be(true)
      end
    end

    context 'SP not in allowed list' do
      it 'does not allow the SP to optionally skip encrypting the SAML response' do
        expect(service_provider.skip_encryption_allowed).to be(false)
      end
    end
  end

  describe '#facial_match_ial_allowed?' do
    context 'when facial match general availability is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:facial_match_general_availability_enabled)
          .and_return(true)
      end

      it 'allows the service provider to use facial match IALs' do
        expect(service_provider.facial_match_ial_allowed?).to be(true)
      end
    end

    context 'when the facial match general availability is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:facial_match_general_availability_enabled)
          .and_return(false)
      end

      it 'does not allow the service provider to use facial match IALs' do
        expect(service_provider.facial_match_ial_allowed?).to be(false)
      end
    end
  end

  describe '#attempts_api_enabled?' do
    context 'when attempts api is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:attempts_api_enabled)
          .and_return(true)
      end

      context 'when the service provider is not on the allowlist for attempts api' do
        it 'returns false' do
          expect(service_provider.attempts_api_enabled?).to be(false)
        end
      end

      context 'when the service provider is on the allowlist for attempts api' do
        before do
          allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
            [{ 'issuer' => service_provider.issuer }],
          )
        end

        it 'returns true' do
          expect(service_provider.attempts_api_enabled?).to be(true)
        end
      end
    end

    context 'when attempts api availability is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:attempts_api_enabled)
          .and_return(false)
      end

      context 'when the service provider is on the allowlist for attempts api' do
        before do
          allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
            [{ 'issuer' => service_provider.issuer }],
          )
        end

        it 'returns false' do
          expect(service_provider.attempts_api_enabled?).to be(false)
        end
      end

      context 'when the service provider is not on the allowlist for attempts api' do
        it 'returns false' do
          expect(service_provider.attempts_api_enabled?).to be(false)
        end
      end
    end
  end

  describe '#attempts_public_key' do
    context 'when the sp is configured to use the attempts api' do
      context 'when there is no public key set in the configuration' do
        before do
          allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
            [{ 'issuer' => service_provider.issuer }],
          )
        end

        it "returns the sp's first public key" do
          expect(service_provider.attempts_public_key.to_pem).to eq(
            service_provider.ssl_certs.first.public_key.to_pem,
          )
        end
      end

      context 'when the public key is set in the configuration' do
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:public_key) { private_key.public_key }

        before do
          allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
            [
              { 'issuer' => service_provider.issuer,
                'keys' => [public_key.to_pem] },

            ],
          )
        end

        it "returns the sp's first public key" do
          expect(service_provider.attempts_public_key.to_pem).to eq(
            public_key.to_pem,
          )
        end
      end
    end
  end

  describe '#ssl_certs' do
    context 'with an empty string plural cert' do
      let(:service_provider) { build(:service_provider, certs: ['']) }

      it 'is the empty array' do
        expect(service_provider.ssl_certs).to eq([])
      end
    end

    let(:pem) { Rails.root.join('certs', 'sp', 'saml_test_sp.crt').read }

    context 'with the PEM of a cert in the plural column' do
      let(:service_provider) { build(:service_provider, certs: [pem]) }

      it 'is an array of the X509 cert' do
        expect(service_provider.ssl_certs.length).to eq(1)
        expect(service_provider.ssl_certs.first).to be_kind_of(OpenSSL::X509::Certificate)
        expect(service_provider.ssl_certs.first.to_pem).to eq(pem)
      end
    end

    context 'with the name of a cert in the plural column' do
      let(:service_provider) { build(:service_provider, certs: ['saml_test_sp']) }

      it 'is an array of the X509 cert' do
        expect(service_provider.ssl_certs.length).to eq(1)
        expect(service_provider.ssl_certs.first).to be_kind_of(OpenSSL::X509::Certificate)
        expect(service_provider.ssl_certs.first.to_pem).to eq(pem)
      end
    end

    context 'when a cert is named in the DB but does not exist on disk' do
      let(:service_provider) { build(:service_provider, certs: ['i_do_not_exist', 'saml_test_sp']) }

      it 'is an array of the existing certs only' do
        expect(service_provider.ssl_certs.length).to eq(1)
        expect(service_provider.ssl_certs.first).to be_kind_of(OpenSSL::X509::Certificate)
        expect(service_provider.ssl_certs.first.to_pem).to eq(pem)
      end
    end
  end

  describe '#logo_is_email_compatible?' do
    subject { ServiceProvider.new(logo: logo) }
    before do
      allow(FeatureManagement).to receive(:logo_upload_enabled?).and_return(true)
    end

    context 'service provider has a png logo' do
      let(:logo) { 'gsa.png' }

      it 'returns true' do
        expect(subject.logo_is_email_compatible?).to be(true)
      end
    end

    context 'service provider has a svg logo' do
      let(:logo) { '18f.svg' }

      it 'returns false' do
        expect(subject.logo_is_email_compatible?).to be(false)
      end
    end

    context 'service provider has no logo' do
      let(:logo) { nil }

      it 'returns false' do
        expect(subject.logo_is_email_compatible?).to be(false)
      end
    end
  end

  describe '#logo_url' do
    let(:logo) { '18f.svg' }
    subject { ServiceProvider.new(logo: logo) }
    context 'service provider has a logo' do
      it 'returns the logo' do
        expect(subject.logo_url).to match(%r{sp-logos/18f-[0-9a-f]+\.svg$})
      end
    end

    context 'service provider does not have a logo' do
      let(:logo) { nil }
      it 'returns the default logo' do
        expect(subject.logo_url).to match(%r{/sp-logos/generic-.+\.svg})
      end
    end

    context 'service provider has a poorly configured logo' do
      let(:logo) { 'abc' }
      it 'does not raise an exception' do
        expect(subject.logo_url).to be_kind_of(String)
      end
    end

    context 'when the logo upload feature is enabled' do
      let(:aws_region) { 'us-west-2' }
      let(:aws_logo_bucket) { 'logo-bucket' }
      let(:remote_logo_key) { 'llave' }
      before do
        allow(FeatureManagement).to receive(:logo_upload_enabled?).and_return(true)
        allow(IdentityConfig.store).to receive(:aws_logo_bucket)
          .and_return(aws_logo_bucket)
      end

      context 'when the remote logo key is present' do
        subject { ServiceProvider.new(logo: logo, remote_logo_key: remote_logo_key) }

        it 'uses the s3_logo_url' do
          expect(subject.logo_url).to match("https://s3.#{aws_region}.amazonaws.com/#{aws_logo_bucket}/#{remote_logo_key}")
        end
      end
    end
  end
end
