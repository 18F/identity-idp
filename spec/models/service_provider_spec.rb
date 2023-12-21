require 'rails_helper'

RSpec.describe ServiceProvider do
  let(:service_provider) { ServiceProvider.find_by(issuer: 'http://localhost:3000') }

  describe 'associations' do
    subject { service_provider }

    it { is_expected.to belong_to(:agency) }
    it do
      is_expected.to have_many(:identities).
        inverse_of(:service_provider_record).
        with_foreign_key('service_provider').
        with_primary_key('issuer')
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
        allow(IdentityConfig.store).to receive(:skip_encryption_allowed_list).
          and_return(['http://localhost:3000'])
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
end
