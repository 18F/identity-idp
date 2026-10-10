require 'rails_helper'

RSpec.describe ServiceProviderUpdater do
  include SamlAuthHelper

  let(:fake_dashboard_url) { 'http://dashboard.example.org' }
  let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
  let(:inactive_dashboard_sp_issuer) { 'old-dashboard-service-provider' }
  let(:oidc_issuer) { 'sp:test:foo:bar' }
  let(:openid_connect_redirect_uris) { %w[http://localhost:1234 my-app://result] }

  let(:agency_1) { create(:agency) }
  let(:agency_2) { create(:agency) }
  let(:agency_3) { create(:agency) }

  let(:friendly_sp) do
    {
      id: 'big number',
      created_at: '2010-01-01 00:00:00'.to_datetime,
      updated_at: '2010-01-01 00:00:00'.to_datetime,
      issuer: dashboard_sp_issuer,
      agency_id: agency_1.id,
      friendly_name: 'a friendly service provider',
      description: 'user friendly Login.gov dashboard',
      acs_url: 'http://sp.example.org/saml/login',
      assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
      block_encryption: 'aes256-cbc',
      certs: [saml_test_sp_cert],
      active: true,
      approved: true,
      help_text: {
        sign_in: { en: '<strong>A new different sign-in help text</strong>' },
        sign_up: { en: '<strong>A new different help text</strong>' },
        forgot_password: { en: '<strong>A new different forgot password help text</strong>' },
      },
    }
  end

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
      certs: [saml_test_sp_cert],
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
      issuer: oidc_issuer,
      friendly_name: 'a service provider',
      agency_id: agency_1.id,
      redirect_uris: openid_connect_redirect_uris,
      active: true,
      certs: [
        saml_test_sp_cert,
        File.read(Rails.root.join('certs', 'sp', 'saml_test_sp2.crt')),
      ],
    }
  end
  let(:dashboard_service_providers) { [friendly_sp, old_sp, nasty_sp, openid_connect_sp] }

  describe '#run' do
    before do
      allow(IdentityConfig.store).to receive(:dashboard_url).and_return(fake_dashboard_url)
    end

    context 'dashboard is available' do
      before do
        stub_request(:get, fake_dashboard_url).to_return(
          status: 200,
          body: dashboard_service_providers.to_json,
        )
      end

      after do
        ServiceProvider.find_by(issuer: dashboard_sp_issuer).try(:destroy)
        ServiceProvider.find_by(issuer: inactive_dashboard_sp_issuer).try(:destroy)
      end

      it 'creates new dashboard-provided Service Providers' do
        subject.run

        sp = ServiceProvider.find_by(issuer: dashboard_sp_issuer)

        expect(sp.agency).to eq agency_1
        expect(sp.ssl_certs.first).to be_a OpenSSL::X509::Certificate
        expect(sp.active?).to eq true
        expect(sp.id).to_not eq 0
        expect(sp.updated_at).to_not eq friendly_sp[:updated_at]
        expect(sp.created_at).to_not eq friendly_sp[:created_at]
        expect(sp.approved).to eq true
        expect(sp.help_text['sign_in']).to eq friendly_sp[:help_text][:sign_in]
          .stringify_keys
        expect(sp.help_text['sign_up']).to eq friendly_sp[:help_text][:sign_up]
          .stringify_keys
        expect(sp.help_text['forgot_password']).to eq friendly_sp[:help_text][:forgot_password]
          .stringify_keys
      end

      it 'updates existing dashboard-provided Service Providers' do
        sp = create(:service_provider, issuer: dashboard_sp_issuer)
        old_id = sp.id

        subject.run

        sp = ServiceProvider.find_by(issuer: dashboard_sp_issuer)

        expect(sp.agency).to eq agency_1
        expect(sp.ssl_certs.first).to be_a OpenSSL::X509::Certificate
        expect(sp.active?).to eq true
        expect(sp.id).to eq old_id
        expect(sp.updated_at).to_not eq friendly_sp[:updated_at]
        expect(sp.created_at).to_not eq friendly_sp[:created_at]
        expect(sp.approved).to eq true
        expect(sp.help_text['sign_in']).to eq friendly_sp[:help_text][:sign_in]
          .stringify_keys
        expect(sp.help_text['sign_up']).to eq friendly_sp[:help_text][:sign_up]
          .stringify_keys
        expect(sp.help_text['forgot_password']).to eq friendly_sp[:help_text][:forgot_password]
          .stringify_keys
      end

      it 'removes inactive Service Providers' do
        expect(ServiceProvider.find_by(issuer: inactive_dashboard_sp_issuer)).to be_nil

        subject.run

        expect(ServiceProvider.find_by(issuer: inactive_dashboard_sp_issuer)).to be_nil
      end

      it 'ignores attempts to alter native Service Providers' do
        subject.run

        sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')

        expect(sp.agency).to_not eq 'trying to override a test SP'
      end

      it 'updates redirect_uris' do
        subject.run

        sp = ServiceProvider.find_by(issuer: oidc_issuer)

        expect(sp.redirect_uris).to eq(openid_connect_redirect_uris)
      end

      it 'updates certs (plural)' do
        expect { subject.run }
          .to(change { ServiceProvider.find_by(issuer: oidc_issuer)&.ssl_certs&.size }.to(2))
      end

      context 'when the payload carries the userinfo encryption opt-in' do
        let(:openid_connect_sp) do
          super().merge(userinfo_encrypted_response_alg: 'RSA-OAEP-256')
        end

        it 'writes it through and does not warn for a confidential client with certificates' do
          warnings = []
          allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

          subject.run

          sp = ServiceProvider.find_by(issuer: oidc_issuer)
          expect(sp.userinfo_encrypted_response_alg).to eq('RSA-OAEP-256')
          expect(sp.userinfo_encryption_key).to be_a(OpenSSL::PKey::RSA)
          expect(warnings.grep(/encrypted userinfo/)).to be_empty
        end

        context 'without certificates' do
          let(:openid_connect_sp) { super().merge(certs: []) }

          it 'writes it through and warns that userinfo requests will be refused' do
            warnings = []
            allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

            subject.run

            expect(ServiceProvider.find_by(issuer: oidc_issuer).userinfo_encrypted_response_alg)
              .to eq('RSA-OAEP-256')
            expect(warnings).to contain_exactly(
              a_string_including(oidc_issuer, 'no usable registered certificate', 'refused'),
            )
          end
        end

        context 'on a public client' do
          let(:openid_connect_sp) { super().merge(pkce: true) }

          it 'warns that userinfo requests will be refused' do
            warnings = []
            allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

            subject.run

            expect(warnings).to contain_exactly(
              a_string_including(oidc_issuer, 'public client', 'refused'),
            )
          end
        end
      end
    end

    context 'dashboard payload carries delegated-access fields and API URLs' do
      let(:application_payload) do
        openid_connect_sp.merge(
          delegation_application: true,
          delegation_scope_value: 'housing_records',
          delegation_display_name: { en: 'Housing Assistance Records' },
          delegation_description: { en: 'check your housing application.' },
          allowed_delegation_service_providers: ['urn:mybenefits'],
          token_exchange_resource_servers: [
            {
              identifier: 'https://records-api.housing.example.gov',
              certs: [saml_test_sp_cert],
              token_format: 'oauth',
            },
            {
              identifier: 'https://documents-api.housing.example.gov',
              certs: [saml_test_sp_cert],
              token_format: 'saml2',
            },
          ],
        )
      end

      it 'writes the application fields and upserts its API URLs, deactivating ones dropped' do
        stub_request(:get, fake_dashboard_url)
          .to_return(status: 200, body: [application_payload].to_json)
        subject.run

        application = ServiceProvider.find_by(issuer: oidc_issuer)
        expect(application.delegation_application).to eq(true)
        expect(application.delegation_scope).to eq('token_exchange:housing_records')
        expect(application.accepts_delegation_from?('urn:mybenefits')).to eq(true)
        expect(application.token_exchange_resource_servers.active.pluck(:identifier))
          .to contain_exactly(
            'https://records-api.housing.example.gov',
            'https://documents-api.housing.example.gov',
          )
        records_api = application.token_exchange_resource_servers
          .find_by(identifier: 'https://records-api.housing.example.gov')
        expect(records_api.certs).to eq([saml_test_sp_cert])

        # The Dashboard drops one URL: it is deactivated, not deleted, so approvals and tokens
        # that reference it keep their foreign keys.
        application_payload[:token_exchange_resource_servers].pop
        stub_request(:get, fake_dashboard_url)
          .to_return(status: 200, body: [application_payload].to_json)
        ServiceProviderUpdater.new.run

        expect(application.token_exchange_resource_servers.active.pluck(:identifier))
          .to eq(['https://records-api.housing.example.gov'])
        expect(
          application.token_exchange_resource_servers
            .find_by(identifier: 'https://documents-api.housing.example.gov').active,
        ).to eq(false)
      end
      it 'warns that an API whose billing issuer has no partner agreement is never invoiced' do
        stub_request(:get, fake_dashboard_url)
          .to_return(status: 200, body: [application_payload].to_json)
        warnings = []
        allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

        subject.run

        # Every API billed to an issuer without an agreement is warned about; the records API
        # must be among them.
        expect(warnings).to include(
          a_string_including(
            'https://records-api.housing.example.gov', oidc_issuer,
            'recorded but not invoiced'
          ),
        )
      end
    end

    context 'dashboard is not available' do
      it 'logs error and does not affect registry' do
        allow(Rails.logger).to receive(:error)
        before_count = ServiceProvider.count

        stub_request(:get, fake_dashboard_url).to_return(status: 500)

        subject.run

        expect(Rails.logger).to have_received(:error)
          .with("Failed to parse response from #{fake_dashboard_url}: ")
        expect(ServiceProvider.count).to eq before_count
      end
    end

    context 'a service provider is invalid' do
      let(:dashboard_service_providers) do
        [
          {
            id: 'big number',
            created_at: '2010-01-01 00:00:00'.to_datetime,
            updated_at: '2010-01-01 00:00:00'.to_datetime,
            issuer: dashboard_sp_issuer,
            agency_id: agency_1.id,
            friendly_name: 'a friendly service provider',
            description: 'user friendly Login.gov dashboard',
            acs_url: 'http://sp.example.org/saml/login',
            assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
            block_encryption: 'aes256-cbc',
            certs: [saml_test_sp_cert],
            active: true,
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

    context 'dashboard has the old singular cert attribute' do
      let(:dashboard_service_providers) do
        [
          {
            issuer: 'aaaaaa',
            friendly_name: 'a service provider',
            agency_id: agency_1.id,
            redirect_uris: openid_connect_redirect_uris,
            active: true,
            cert: 'aaaa',
          },
        ]
      end

      it 'ignores the old column' do
        stub_request(:get, fake_dashboard_url).to_return(
          status: 200,
          body: dashboard_service_providers.to_json,
        )
        expect { subject.run }.to_not raise_error
      end
    end
    context 'GET request to dashboard raises an error' do
      it 'logs error and does not affect registry' do
        allow(Rails.logger).to receive(:error)
        before_count = ServiceProvider.count

        stub_request(:get, fake_dashboard_url).and_raise(SocketError)

        subject.run

        expect(Rails.logger).to have_received(:error)
          .with("Failed to contact #{fake_dashboard_url}")
        expect(ServiceProvider.count).to eq before_count
      end
    end

    context 'run is called with service_provider attributes' do
      let(:attributes) { friendly_sp.except(:id) }
      let(:friendly_name) { 'A different name' }

      before { attributes[:friendly_name] = friendly_name }

      it 'does not try to send a GET to the dashboard' do
        expect(Faraday).not_to receive(:get)

        subject.run(attributes)
      end

      context 'service provider attributes has active: true' do
        context 'service provider exists' do
          let(:sp) { create(:service_provider, issuer: attributes[:issuer]) }
          it 'updates the single service provider' do
            subject.run(attributes)

            sp = ServiceProvider.find_by(issuer: attributes[:issuer])

            expect(sp.friendly_name).to eq friendly_name
          end
        end

        context 'service provider does not yet exist' do
          it 'creates the service provider' do
            expect(ServiceProvider.find_by(issuer: attributes[:issuer])).to be nil

            subject.run(attributes)

            sp = ServiceProvider.find_by(issuer: attributes[:issuer])

            expect(sp.friendly_name).to eq friendly_name
          end
        end
      end

      context 'service provider attributes has active: false' do
        let(:sp) { create(:service_provider, issuer: attributes[:issuer]) }
        before { attributes[:active] = false }

        it 'destroys the service_provider' do
          subject.run(attributes)

          destroyed_sp = ServiceProvider.find_by(issuer: attributes[:issuer])

          expect(destroyed_sp).to be nil
        end
      end
    end
  end
end
