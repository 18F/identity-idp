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

  describe '#document_images_sharing_allowed?' do
    context 'when sharing is enabled and the issuer is allow-listed' do
      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([service_provider.issuer])
      end

      it 'is true' do
        expect(service_provider.document_images_sharing_allowed?).to be(true)
      end
    end

    context 'when sharing is enabled but the issuer is not allow-listed' do
      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([])
      end

      it 'is false' do
        expect(service_provider.document_images_sharing_allowed?).to be(false)
      end
    end

    context 'when sharing is disabled globally' do
      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(false)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([service_provider.issuer])
      end

      it 'is false' do
        expect(service_provider.document_images_sharing_allowed?).to be(false)
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

  describe '#create_prompt_allowed?' do
    context 'when the sp is not on the allowlist for the "create" prompt' do
      it 'returns false' do
        expect(service_provider.create_prompt_allowed?).to be(false)
      end
    end

    context 'when the sp is on the allowlist for the "create" prompt' do
      before do
        allow(IdentityConfig.store).to receive(:allowed_create_prompt_providers).and_return(
          ['an-issuer', service_provider.issuer],
        )
      end

      it 'returns true' do
        expect(service_provider.create_prompt_allowed?).to be(true)
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
    subject { ServiceProvider.new }
    let(:logo_url_mock) { LogoUrl.new(subject.logo, subject.remote_logo_key) }
    let(:expected_value) { "/file-#{rand(1..10000)}.png" }

    it 'returns whatever the LogoUrl class provides' do
      expect(LogoUrl).to receive(:new).and_return(logo_url_mock)
      expect(logo_url_mock).to receive(:url).and_return(expected_value)
      actual_value = subject.logo_url
      expect(actual_value).to eq(expected_value)
    end
  end

  describe '#receives_client_id_in_risc?' do
    context 'when client is included in allowlist' do
      before do
        expect(IdentityConfig.store).to receive(:allowed_client_id_in_risc_service_providers)
          .and_return([subject.issuer])
      end

      it 'returns true' do
        expect(subject.receives_client_id_in_risc?).to be true
      end
    end

    context 'when client is not included in allowlist' do
      before do
        expect(IdentityConfig.store).to receive(:allowed_client_id_in_risc_service_providers)
          .and_return(['another-issuer'])
      end

      it 'returns true' do
        expect(subject.receives_client_id_in_risc?).to be false
      end
    end
  end

  describe '#delegation_application?' do
    it 'is true only for an active record registered as an application' do
      expect(create(:service_provider, :delegation_application).delegation_application?).to eq(true)
      expect(
        create(:service_provider, :delegation_application, active: false)
                .delegation_application?,
      ).to eq(false)
      expect(create(:service_provider, :active).delegation_application?).to eq(false)
    end
  end

  describe '#delegation_scope' do
    it 'prefixes the scope value with token_exchange:' do
      application = create(
        :service_provider, :delegation_application, delegation_scope_value: 'housing_records'
      )
      expect(application.delegation_scope).to eq('token_exchange:housing_records')
    end

    it 'is nil for a record without a scope value' do
      expect(create(:service_provider, :active).delegation_scope).to be_nil
    end
  end

  describe '#accepts_delegation_from?' do
    let(:issuer) { 'urn:gov:gsa:openidconnect:sp:mybenefits' }

    it 'accepts any service provider when the list is empty' do
      application = create(:service_provider, :delegation_application)
      expect(application.accepts_delegation_from?(issuer)).to eq(true)
    end

    it 'accepts only the listed service providers when the list is set' do
      application = create(
        :service_provider, :delegation_application,
        allowed_delegation_service_providers: [issuer]
      )
      expect(application.accepts_delegation_from?(issuer)).to eq(true)
      expect(application.accepts_delegation_from?('urn:someone-else')).to eq(false)
    end

    it 'accepts nobody when the record is not an application' do
      expect(create(:service_provider, :active).accepts_delegation_from?(issuer)).to eq(false)
    end
  end

  describe 'localized consent content' do
    it 'reads the current locale and falls back to English' do
      application = create(
        :service_provider, :delegation_application,
        delegation_display_name: { en: 'Housing Assistance Records', es: 'Registros de vivienda' },
        delegation_description: { en: 'check your housing application.' }
      )
      expect(application.delegation_display_name_for(:es)).to eq('Registros de vivienda')
      expect(application.delegation_display_name_for(:fr)).to eq('Housing Assistance Records')
      expect(application.delegation_description_for(:zh)).to eq('check your housing application.')
    end
  end

  describe '#delegation_service_provider?' do
    before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

    it 'is true for an active, approved service provider' do
      expect(create(:service_provider, :delegation_service_provider).delegation_service_provider?)
        .to eq(true)
    end

    it 'is false without approval, when inactive, or when the capability is off' do
      expect(create(:service_provider, :active).delegation_service_provider?).to eq(false)
      expect(
        create(:service_provider, :delegation_service_provider, active: false)
                .delegation_service_provider?,
      ).to eq(false)

      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false)
      expect(create(:service_provider, :delegation_service_provider).delegation_service_provider?)
        .to eq(false)
    end
  end
end
