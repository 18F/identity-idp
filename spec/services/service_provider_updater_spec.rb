require 'rails_helper'

describe ServiceProviderUpdater do
  include SamlAuthHelper

  let(:fake_dashboard_url) { 'http://dashboard.example.org' }
  let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
  let(:inactive_dashboard_sp_issuer) { 'old-dashboard-service-provider' }
  let(:openid_connect_issuer) { 'sp:test:foo:bar' }
  let(:openid_connect_redirect_uris) { %w[http://localhost:1234 my-app://result] }

  let(:agency_1) { create(:agency) }
  let(:agency_2) { create(:agency) }
  let(:agency_3) { create(:agency) }

  # rubocop:disable Style/TrailingCommaInHashLiteral
  let(:friendly_sp) do
    {
      id: 'big number',
      created_at: '2010-01-01 00:00:00'.to_datetime,
      updated_at: '2010-01-01 00:00:00'.to_datetime,
      issuer: dashboard_sp_issuer,
      agency_id: agency_1.id,
      friendly_name: 'a friendly service provider',
      description: 'user friendly login.gov dashboard',
      acs_url: 'http://sp.example.org/saml/login',
      assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
      block_encryption: 'aes256-cbc',
      cert: saml_test_sp_cert,
      active: true,
      native: true,
      approved: true,
      help_text: { 'sign_in': { en: '<b>A new different sign-in help text</b>' },
                   'sign_up': { en: '<b>A new different help text</b>' },
                   'forgot_password': { en: '<b>A new different forgot password help text</b>' }, }
    }
  end
  # rubocop:enable Style/TrailingCommaInHashLiteral
  let(:old_sp) do
    {
      id: 'small number',
      updated_at: '2010-01-01 00:00:00',
      issuer: inactive_dashboard_sp_issuer,
      agency_id: agency_2.id,
      friendly_name: 'an old, stale service provider',
      description: 'forget about me',
      acs_url: 'http://oldsp.example.org/saml/login',
      assertion_consumer_logout_service_url: 'http://oldsp.example.org/saml/logout',
      block_encryption: 'aes256-cbc',
      cert: saml_test_sp_cert,
      active: false,
    }
  end
  let(:nasty_sp) do
    {
      issuer: 'http://localhost:3000',
      friendly_name: 'trying to override a test SP',
      agency_id: agency_3.id,
      acs_url: 'http://nasty-override.example.org/saml/login',
      active: true,
    }
  end
  let(:openid_connect_sp) do
    {
      issuer: openid_connect_issuer,
      friendly_name: 'a service provider',
      agency_id: agency_1.id,
      redirect_uris: openid_connect_redirect_uris,
      active: true,
    }
  end
  let(:dashboard_service_providers) { [friendly_sp, old_sp, nasty_sp, openid_connect_sp] }

  describe '#run' do
    before do
      allow(AppConfig.env).to receive(:dashboard_url).and_return(fake_dashboard_url)
    end

    context 'dashboard is available' do
      before do
        stub_request(:get, fake_dashboard_url).to_return(
          status: 200,
          body: dashboard_service_providers.to_json,
        )
      end

      after do
        ServiceProvider.from_issuer(dashboard_sp_issuer).try(:destroy)
        ServiceProvider.from_issuer(inactive_dashboard_sp_issuer).try(:destroy)
      end

      it 'creates new dashboard-provided Service Providers' do
        subject.run

        sp = ServiceProvider.from_issuer(dashboard_sp_issuer)

        expect(sp.agency).to eq agency_1
        expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
        expect(sp.active?).to eq true
        expect(sp.id).to_not eq 0
        expect(sp.updated_at).to_not eq friendly_sp[:updated_at]
        expect(sp.created_at).to_not eq friendly_sp[:created_at]
        expect(sp.native).to eq false
        expect(sp.approved).to eq true
        expect(sp.help_text['sign_in']).to eq friendly_sp[:help_text][:sign_in].
          stringify_keys
        expect(sp.help_text['sign_up']).to eq friendly_sp[:help_text][:sign_up].
          stringify_keys
        expect(sp.help_text['forgot_password']).to eq friendly_sp[:help_text][:forgot_password].
          stringify_keys
      end

      it 'updates existing dashboard-provided Service Providers' do
        sp = create(:service_provider, issuer: dashboard_sp_issuer)
        old_id = sp.id

        subject.run

        sp = ServiceProvider.from_issuer(dashboard_sp_issuer)

        expect(sp.agency).to eq agency_1
        expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
        expect(sp.active?).to eq true
        expect(sp.id).to eq old_id
        expect(sp.updated_at).to_not eq friendly_sp[:updated_at]
        expect(sp.created_at).to_not eq friendly_sp[:created_at]
        expect(sp.native).to eq false
        expect(sp.approved).to eq true
        expect(sp.help_text['sign_in']).to eq friendly_sp[:help_text][:sign_in].
          stringify_keys
        expect(sp.help_text['sign_up']).to eq friendly_sp[:help_text][:sign_up].
          stringify_keys
        expect(sp.help_text['forgot_password']).to eq friendly_sp[:help_text][:forgot_password].
          stringify_keys
      end

      it 'removes inactive Service Providers' do
        expect(ServiceProvider.from_issuer(inactive_dashboard_sp_issuer)).
          to be_a NullServiceProvider

        subject.run

        sp = ServiceProvider.from_issuer(inactive_dashboard_sp_issuer)

        expect(sp).to be_a NullServiceProvider
      end

      it 'ignores attempts to alter native Service Providers' do
        subject.run

        sp = ServiceProvider.from_issuer('http://localhost:3000')

        expect(sp.agency).to_not eq 'trying to override a test SP'
      end

      it 'updates redirect_uris' do
        subject.run

        sp = ServiceProvider.from_issuer(openid_connect_issuer)

        expect(sp.redirect_uris).to eq(openid_connect_redirect_uris)
      end
    end

    context 'dashboard is not available' do
      it 'logs error and does not affect registry' do
        allow(Rails.logger).to receive(:error)
        before_count = ServiceProvider.count

        stub_request(:get, fake_dashboard_url).to_return(status: 500)

        subject.run

        expect(Rails.logger).to have_received(:error).
          with("Failed to parse response from #{fake_dashboard_url}: ")
        expect(ServiceProvider.count).to eq before_count
      end
    end

    context 'a non-native service provider is invalid' do
      let(:dashboard_service_providers) do
        [
          {
            id: 'big number',
            created_at: '2010-01-01 00:00:00'.to_datetime,
            updated_at: '2010-01-01 00:00:00'.to_datetime,
            issuer: dashboard_sp_issuer,
            agency_id: agency_1.id,
            friendly_name: 'a friendly service provider',
            description: 'user friendly login.gov dashboard',
            acs_url: 'http://sp.example.org/saml/login',
            assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
            block_encryption: 'aes256-cbc',
            cert: saml_test_sp_cert,
            active: true,
            native: false,
            approved: true,
            redirect_uris: [''],
          },
        ]
      end

      it 'raises an error' do
        stub_request(:get, fake_dashboard_url).to_return(
          status: 200,
          body: dashboard_service_providers.to_json,
        )
        expect { subject.run }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'GET request to dashboard raises an error' do
      it 'logs error and does not affect registry' do
        allow(Rails.logger).to receive(:error)
        before_count = ServiceProvider.count

        stub_request(:get, fake_dashboard_url).and_raise(SocketError)

        subject.run

        expect(Rails.logger).to have_received(:error).
          with("Failed to contact #{fake_dashboard_url}")
        expect(ServiceProvider.count).to eq before_count
      end
    end
  end
end
