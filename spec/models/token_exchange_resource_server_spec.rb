require 'rails_helper'

RSpec.describe TokenExchangeResourceServer do
  let(:resource_server) { create(:token_exchange_resource_server) }

  it 'requires a unique identifier and a known token format' do
    duplicate = build(:token_exchange_resource_server, identifier: resource_server.identifier)
    expect(duplicate).not_to be_valid
    expect(build(:token_exchange_resource_server, token_format: 'jwt')).not_to be_valid
    expect(build(:token_exchange_resource_server, :saml)).to be_valid
  end

  describe '#ssl_certs' do
    it 'loads a certificate by name from certs/sp, as ServiceProvider does' do
      expect(resource_server.ssl_certs.first).to be_a(OpenSSL::X509::Certificate)
    end

    it 'accepts an inline PEM certificate, so a sandbox needs no file on disk' do
      pem = Rails.root.join('certs', 'sp', 'saml_test_sp.crt').read
      inline = create(:token_exchange_resource_server, certs: [pem])
      expect(inline.ssl_certs.first.to_pem).to eq(OpenSSL::X509::Certificate.new(pem).to_pem)
    end
  end

  it 'defaults the Attempts recipient and the billing issuer to the owning application' do
    expect(resource_server.attempts_recipient).to eq(resource_server.service_provider)
    expect(resource_server.billing_issuer_value).to eq(resource_server.service_provider.issuer)

    other = create(:service_provider)
    resource_server.update!(attempts_service_provider: other, billing_issuer: 'urn:billing')
    expect(resource_server.attempts_recipient).to eq(other)
    expect(resource_server.billing_issuer_value).to eq('urn:billing')
  end

  describe '#billing_issuer_has_agreement?' do
    it 'is false when no integration carries the billing issuer' do
      expect(resource_server.billing_issuer_has_agreement?).to eq(false)
    end

    it 'is true when an integration carries the billing issuer' do
      create(:integration, issuer: resource_server.billing_issuer_value)
      expect(resource_server.billing_issuer_has_agreement?).to eq(true)
    end
  end

  describe '#usable?' do
    it 'is true while the URL and its application are active' do
      expect(resource_server.usable?).to eq(true)
    end

    it 'is false once the URL is deactivated' do
      resource_server.update!(active: false)
      expect(resource_server.usable?).to eq(false)
    end

    it 'is false once the application is deactivated or no longer registered' do
      resource_server.service_provider.update!(active: false)
      expect(resource_server.reload.usable?).to eq(false)

      resource_server.service_provider.update!(active: true, delegation_application: false)
      expect(resource_server.reload.usable?).to eq(false)
    end
  end
end
