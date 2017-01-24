require 'rails_helper'

describe ServiceProviderUpdater do
  include SamlAuthHelper

  let(:fake_dashboard_url) { 'http://dashboard.example.org' }
  let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
  let(:dashboard_service_providers) do
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

  describe '#run' do
    before do
      allow(Figaro.env).to receive(:dashboard_url).and_return(fake_dashboard_url)
    end

    context 'dashboard is available' do
      before do
        stub_request(:get, fake_dashboard_url).to_return(
          status: 200,
          body: dashboard_service_providers.to_json
        )
        SERVICE_PROVIDERS.delete dashboard_sp_issuer
        VALID_SERVICE_PROVIDERS.delete dashboard_sp_issuer
      end

      after do
        SERVICE_PROVIDERS.delete dashboard_sp_issuer
        VALID_SERVICE_PROVIDERS.delete dashboard_sp_issuer
      end

      it 'updates global var registry of Service Providers' do
        expect(SERVICE_PROVIDERS[dashboard_sp_issuer]).to eq nil
        expect(VALID_SERVICE_PROVIDERS).to_not include dashboard_sp_issuer

        subject.run

        sp = ServiceProvider.new(dashboard_sp_issuer)

        expect(sp.metadata[:agency]).to eq dashboard_service_providers.first[:agency]
        expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
        expect(sp.valid?).to eq true
        expect(VALID_SERVICE_PROVIDERS).to include dashboard_sp_issuer
      end
    end

    context 'dashboard is not available' do
      it 'logs error and does not affect registry' do
        allow(subject).to receive(:log_error)

        valid_service_providers = VALID_SERVICE_PROVIDERS.dup

        stub_request(:get, fake_dashboard_url).to_return(status: 500)

        subject.run

        expect(subject).to have_received(:log_error)
        expect(valid_service_providers).to eq VALID_SERVICE_PROVIDERS
      end
    end
  end
end
