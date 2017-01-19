require 'rails_helper'

describe ServiceProviderUpdater do
  include SamlAuthHelper

  let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
  let(:array_of_sps) do
    [
      {
        issuer: dashboard_sp_issuer,
        agency: 'a service provider',
        friendly_name: 'a friendly service provider',
        description: 'user friendly login.gov dashboard',
        acs_url: 'http://sp.example.org/saml/login',
        assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
        block_encryption: 'aes256-cbc',
        cert: saml_test_sp_cert
      }
    ]
  end

  before do
    allow(subject).to receive(:dashboard_service_providers).and_return(array_of_sps)
  end

  describe '#run' do
    it 'updates global var registry of Service Providers' do
      expect(SERVICE_PROVIDERS[dashboard_sp_issuer]).to eq nil
      expect(VALID_SERVICE_PROVIDERS).to_not include dashboard_sp_issuer

      subject.run

      sp = ServiceProvider.new(dashboard_sp_issuer)

      expect(sp.metadata[:agency]).to eq array_of_sps.first[:agency]
      expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
      expect(sp.valid?).to eq true
      expect(VALID_SERVICE_PROVIDERS).to include dashboard_sp_issuer
    end
  end
end
