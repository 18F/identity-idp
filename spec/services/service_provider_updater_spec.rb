require 'rails_helper'

describe ServiceProviderUpdater do
  include SamlAuthHelper

  let(:fake_dashboard_url) { 'http://dashboard.example.org' }
  let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
  let(:inactive_dashboard_sp_issuer) { 'old-dashboard-service-provider' }
  let(:dashboard_service_providers) do
    [
      {
        id: 'big number',
        updated_at: '2010-01-01 00:00:00',
        issuer: dashboard_sp_issuer,
        agency: 'a service provider',
        friendly_name: 'a friendly service provider',
        description: 'user friendly login.gov dashboard',
        acs_url: 'http://sp.example.org/saml/login',
        assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
        block_encryption: 'aes256-cbc',
        cert: saml_test_sp_cert,
        active: true,
      },
      {
        id: 'small number',
        updated_at: '2010-01-01 00:00:00',
        issuer: inactive_dashboard_sp_issuer,
        agency: 'an old service provider',
        friendly_name: 'an old, stale service provider',
        description: 'forget about me',
        acs_url: 'http://oldsp.example.org/saml/login',
        assertion_consumer_logout_service_url: 'http://oldsp.example.org/saml/logout',
        block_encryption: 'aes256-cbc',
        cert: saml_test_sp_cert,
        active: false,
      },
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
      end

      after do
        ServiceProvider.from_issuer(dashboard_sp_issuer).try(:destroy)
        ServiceProvider.from_issuer(inactive_dashboard_sp_issuer).try(:destroy)
      end

      it 'updates global var registry of Service Providers' do
        expect(ServiceProvider.from_issuer(dashboard_sp_issuer)).to be_a NullServiceProvider

        subject.run

        sp = ServiceProvider.from_issuer(dashboard_sp_issuer)

        expect(sp.agency).to eq dashboard_service_providers.first[:agency]
        expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
        expect(sp.active?).to eq true
        expect(sp.id).to_not eq dashboard_service_providers.first[:id]
        expect(sp.updated_at).to_not eq dashboard_service_providers.first[:updated_at]
      end

      it 'removes inactive Service Providers' do
        expect(ServiceProvider.from_issuer(inactive_dashboard_sp_issuer)).
          to be_a NullServiceProvider

        subject.run

        sp = ServiceProvider.from_issuer(inactive_dashboard_sp_issuer)

        expect(sp).to be_a NullServiceProvider
      end
    end

    context 'dashboard is not available' do
      it 'logs error and does not affect registry' do
        allow(subject).to receive(:log_error)
        before_count = ServiceProvider.count

        stub_request(:get, fake_dashboard_url).to_return(status: 500)

        subject.run

        expect(subject).to have_received(:log_error)
        expect(ServiceProvider.count).to eq before_count
      end
    end
  end
end
