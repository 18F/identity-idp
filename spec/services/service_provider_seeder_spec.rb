require 'rails_helper'

RSpec.describe ServiceProviderSeeder do
  subject(:instance) { ServiceProviderSeeder.new(rails_env: rails_env, deploy_env: deploy_env) }
  let(:rails_env) { 'test' }
  let(:deploy_env) { 'int' }

  describe '#run' do
    before do
      Agreements::IntegrationUsage.delete_all
      Agreements::Integration.delete_all
      ServiceProvider.delete_all
    end

    subject(:run) { instance.run }

    it 'inserts service providers into the database from service_providers.yml' do
      expect { run }.to change(ServiceProvider, :count)
    end

    it 'sets site_key_allowed from the yaml' do
      run

      expect(ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:test').site_key_allowed)
        .to eq(true)
      expect(ServiceProvider.find_by(issuer: 'http://localhost:3000').site_key_allowed)
        .to eq(false)
    end

    it 'updates the plural certs column with the PEM content of certs' do
      cert_names = ['saml_test_sp', 'saml_test_sp2']
      pems = cert_names.map { |cert| Rails.root.join('certs', 'sp', "#{cert}.crt").read }

      run

      sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
      expect(sp.certs).to eq(pems)
    end

    context 'with a delegated-access application and its API URLs in the yaml' do
      let(:inline_pem) { Rails.root.join('certs', 'sp', 'saml_test_sp2.crt').read }
      let(:sp_yaml) do
        <<~SP_YAML
          test:
            'urn:gov:gsa:openidconnect:sp:mybenefits':
              agency_id: 2
              friendly_name: 'MyBenefits Assistant'
              ial: 2
              certs:
                - 'saml_test_sp'
              token_exchange_enabled_sp: true
              delegation_operator_legal_name: 'Office of Benefits Coordination'
              delegation_service_description:
                en: 'helps you find benefits you may qualify for.'
            'urn:gov:gsa:openidconnect:sp:housing_records':
              agency_id: 2
              friendly_name: 'Housing Assistance Records'
              ial: 2
              certs:
                - 'saml_test_sp'
              userinfo_encrypted_response_alg: 'RSA-OAEP-256'
              delegation_application: true
              delegation_scope_value: 'housing_records'
              delegation_display_name:
                en: 'Housing Assistance Records'
              delegation_description:
                en: 'check where your housing application is in review.'
              delegation_data_provided:
                en: ['Case number', 'Current status']
              delegation_access_type: 'read'
              allowed_delegation_service_providers:
                - 'urn:gov:gsa:openidconnect:sp:mybenefits'
              attribute_bundle:
                - email
                - first_name
              delegation_sp_shareable_attributes:
                - first_name
              token_exchange_resource_servers:
                - identifier: 'https://records-api.housing.example.gov'
                  certs:
                    - 'saml_test_sp'
                  token_format: 'oauth'
                - identifier: 'https://documents-api.housing.example.gov'
                  certs:
                    - |
          #{inline_pem.gsub(/^/, '            ')}
                  token_format: 'saml2'
                  attempts_service_provider: 'urn:gov:gsa:openidconnect:sp:mybenefits'
        SP_YAML
      end

      before do
        allow(instance).to receive(:service_provider_data).and_return(sp_yaml)
      end

      it 'writes the service provider and application fields through to the records' do
        run

        sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits')
        expect(sp.token_exchange_enabled_sp).to eq(true)
        expect(sp.delegation_service_description_for(:en))
          .to eq('helps you find benefits you may qualify for.')

        app = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:housing_records')
        expect(app.delegation_application).to eq(true)
        expect(app.delegation_scope).to eq('token_exchange:housing_records')
        expect(app.delegation_display_name_for(:en)).to eq('Housing Assistance Records')
        expect(app.delegation_data_provided_for(:en)).to eq(['Case number', 'Current status'])
        expect(app.accepts_delegation_from?('urn:gov:gsa:openidconnect:sp:mybenefits')).to eq(true)
        expect(app.attribute_bundle).to eq(%w[email first_name])
        expect(app.delegation_sp_shareable_attributes).to eq(%w[first_name])
      end

      it 'leaves the shareable attribute list empty for an application that names none' do
        run
        sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits')
        expect(sp.delegation_sp_shareable_attributes).to eq([])
      end

      it 'writes the userinfo encryption opt-in through, nil for a record that has none' do
        run

        app = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:housing_records')
        expect(app.userinfo_encrypted_response_alg).to eq('RSA-OAEP-256')
        expect(app.userinfo_encrypted_response?).to eq(true)
        expect(app.userinfo_encryption_key).to be_a(OpenSSL::PKey::RSA)
        sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits')
        expect(sp.userinfo_encrypted_response_alg).to be_nil
      end

      it 'does not warn about encryption for an opted-in record with a certificate' do
        warnings = []
        allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

        run

        expect(warnings.grep(/encrypted userinfo/)).to be_empty
      end

      context 'when the opted-in record has no certificate or is a public client' do
        let(:sp_yaml) do
          <<~SP_YAML
            test:
              'urn:gov:gsa:openidconnect:sp:no_certificate':
                agency_id: 2
                friendly_name: 'Opted in without a certificate'
                ial: 2
                userinfo_encrypted_response_alg: 'RSA-OAEP-256'
              'urn:gov:gsa:openidconnect:sp:public_client':
                agency_id: 2
                friendly_name: 'Opted-in public client'
                ial: 2
                pkce: true
                certs:
                  - 'saml_test_sp'
                userinfo_encrypted_response_alg: 'RSA-OAEP-256'
          SP_YAML
        end

        it 'writes the records and warns that their userinfo requests will be refused' do
          warnings = []
          allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

          run

          expect(
            ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:no_certificate')
              .userinfo_encrypted_response_alg,
          ).to eq('RSA-OAEP-256')
          expect(warnings).to contain_exactly(
            a_string_including(
              'urn:gov:gsa:openidconnect:sp:no_certificate',
              'no usable registered certificate', 'refused'
            ),
            a_string_including(
              'urn:gov:gsa:openidconnect:sp:public_client', 'public client', 'refused'
            ),
          )
        end
      end

      it 'upserts the API URLs by identifier, with certificates by name or inline, idempotently' do
        run
        run

        app = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:housing_records')
        expect(app.token_exchange_resource_servers.count).to eq(2)

        records_api = app.token_exchange_resource_servers
          .find_by(identifier: 'https://records-api.housing.example.gov')
        expect(records_api.certs).to eq([Rails.root.join('certs', 'sp', 'saml_test_sp.crt').read])
        expect(records_api.token_format).to eq('oauth')

        documents_api = app.token_exchange_resource_servers
          .find_by(identifier: 'https://documents-api.housing.example.gov')
        expect(documents_api.certs.first.strip).to eq(inline_pem.strip)
        expect(documents_api.token_format).to eq('saml2')
        expect(documents_api.attempts_recipient.issuer)
          .to eq('urn:gov:gsa:openidconnect:sp:mybenefits')
      end
      it 'warns that an API whose billing issuer has no partner agreement is never invoiced' do
        warnings = []
        allow(Rails.logger).to receive(:warn) { |&block| warnings << block.call }

        run

        # Every API billed to an issuer without an agreement is warned about; the records API
        # must be among them.
        expect(warnings).to include(
          a_string_including(
            'https://records-api.housing.example.gov',
            'urn:gov:gsa:openidconnect:sp:housing_records', 'recorded but not invoiced'
          ),
        )
      end

      it 'does not warn when the billing issuer has a partner agreement' do
        allow_any_instance_of(TokenExchangeResourceServer)
          .to receive(:billing_issuer_has_agreement?).and_return(true)
        allow(Rails.logger).to receive(:warn)

        run

        expect(Rails.logger).not_to have_received(:warn)
      end
    end

    context 'with other existing service providers in the database' do
      let!(:existing_provider) { create(:service_provider) }

      it 'sets approved, active and native on service providers from the yaml' do
        run

        config_sp = ServiceProvider.find_by(issuer: 'http://test.host')
        expect(config_sp.approved).to eq(true)
        expect(config_sp.active).to eq(true)
        expect(config_sp.native).to eq(true)

        expect(config_sp.launch_date).to eq(Date.new(2020, 3, 1))
        expect(config_sp.iaa).to eq('ABC123-2020')
        expect(config_sp.iaa_start_date).to eq(Date.new(2020, 1, 1))
        expect(config_sp.iaa_end_date).to eq(Date.new(2020, 12, 31))
      end

      it 'does not change approve, active and native on the other existing service providers' do
        run

        existing_provider.reload
        expect(existing_provider.approved).to_not eq(true)
        expect(existing_provider.active).to_not eq(true)
        expect(existing_provider.native).to_not eq(true)
      end
    end

    context 'when a service provider already exists in the database' do
      before do
        create(
          :service_provider,
          issuer: 'http://test.host',
          acs_url: 'http://test.host/test/saml/decode_assertion_old',
          certs: ['a', 'b'],
        )
      end

      it 'updates the attributes based on the current value of the yml file' do
        expect { run }.to(
          change { ServiceProvider.find_by(issuer: 'http://test.host').acs_url }
            .to('http://test.host/test/saml/decode_assertion').and(
              change { ServiceProvider.find_by(issuer: 'http://test.host').certs }
                .to([Rails.root.join('certs', 'sp', 'saml_test_sp.crt').read]),
            ),
        )
      end
    end

    context 'when running in a production environment' do
      let(:rails_env) { 'production' }
      let(:sandbox_issuer) { 'urn:gov:login:test-providers:fake-sandbox-sp' }
      let(:staging_issuer) { 'urn:gov:login:test-providers:fake-staging-sp' }
      let(:prod_issuer) { 'urn:gov:login:test-providers:fake-prod-sp' }
      let(:unrestricted_issuer) { 'urn:gov:login:test-providers:fake-unrestricted-sp' }

      before do
        allow(IdentityConfig.store).to receive(:team_ursula_email).and_return('team@example.com')
      end

      context 'when %{env} is present in the config file' do
        let(:deploy_env) { 'dev' }

        it 'is replaced with the deploy_env' do
          run

          sp = ServiceProvider.find_by(issuer: sandbox_issuer)
          expect(sp.redirect_uris).to eq(%w[https://dev.example.com])
        end
      end

      context 'in prod' do
        let(:deploy_env) { 'prod' }

        it 'only writes configs with restrict_to_deploy_env for prod' do
          run

          expect(ServiceProvider.find_by(issuer: prod_issuer)).to be_present
          expect(ServiceProvider.find_by(issuer: sandbox_issuer)).not_to be_present
          expect(ServiceProvider.find_by(issuer: staging_issuer)).not_to be_present
          expect(ServiceProvider.find_by(issuer: unrestricted_issuer)).not_to be_present
        end

        it 'sends an email an error if the DB has an SP not in the config' do
          create(:service_provider, issuer: 'missing_issuer')

          expect { run }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end
      end

      context 'in the staging environment' do
        let(:deploy_env) { 'staging' }

        it 'only writes configs with restrict_to_deploy_env for that env, or no restrictions' do
          run

          expect(ServiceProvider.find_by(issuer: staging_issuer)).to be_present
          expect(ServiceProvider.find_by(issuer: unrestricted_issuer)).to be_present
          expect(ServiceProvider.find_by(issuer: sandbox_issuer)).not_to be_present
          expect(ServiceProvider.find_by(issuer: prod_issuer)).not_to be_present
        end

        it 'sends New Relic an error if the DB has an SP not in the config' do
          create(:service_provider, issuer: 'missing_issuer')

          expect { run }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end
      end

      context 'in another environment' do
        let(:deploy_env) { 'int' }

        it 'only writes configs with restrict_to_deploy_env for sandbox' do
          run

          expect(ServiceProvider.find_by(issuer: sandbox_issuer)).to be_present
          expect(ServiceProvider.find_by(issuer: unrestricted_issuer)).to be_present
          expect(ServiceProvider.find_by(issuer: staging_issuer)).not_to be_present
          expect(ServiceProvider.find_by(issuer: prod_issuer)).not_to be_present
        end

        it 'does not send New Relic an error if the DB has an SP not in the config' do
          allow(NewRelic::Agent).to receive(:notice_error)
          create(:service_provider, issuer: 'missing_issuer')
          run

          expect(NewRelic::Agent).not_to have_received(:notice_error)
        end
      end

      context 'when a service provider is invalid' do
        it 'raises an error' do
          invalid_service_providers = {
            'https://rp2.serviceprovider.com/auth/saml/metadata' => {
              acs_url: 'http://example.com/test/saml/decode_assertion',
              assertion_consumer_logout_service_url: 'http://example.com/test/saml/decode_slo_request',
              block_encryption: 'aes256-cbc',
              certs: ['saml_test_sp'],
              redirect_uris: [''],
            },
          }

          expect(instance).to receive(:service_providers).and_return(invalid_service_providers)
          expect { run }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end

    context 'when there is a syntax error in the service_provider.yml config file' do
      let(:seeder) do
        ServiceProviderSeeder.new
      end
      before do
        allow(YAML).to receive(:safe_load).and_raise(
          Psych::SyntaxError.new('file', 0, 0, 0, 'problem', 'context'),
        )
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error)
        begin
          seeder.send(:service_providers)
        rescue Psych::SyntaxError
          # ignore
        end
      end

      it 're-raises the error' do
        expect { seeder.send(:service_providers) }.to raise_error(Psych::SyntaxError)
      end
    end

    context 'when the rails environment is not in the service_provider.yml config file' do
      let(:seeder) do
        ServiceProviderSeeder.new(
          rails_env: 'non-existant environment',
          deploy_env: 'non-existant environment',
        )
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error)
        begin
          seeder.send(:service_providers)
        rescue KeyError
          # ignore
        end
      end

      it 're-raises the error' do
        expect { seeder.send(:service_providers) }.to raise_error(KeyError)
      end
    end
  end

  describe '#run_review_app' do
    let(:dashboard_review_slug) { "review-branch-#{rand 1..1000}" }
    let(:dashboard_url) { "https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov" }
    let(:mock_yaml_file) do
      mock = object_double(Rails.root.join('config', 'service_providers.yml'))
      allow(mock).to receive(:exist?).and_return true
      allow(mock).to receive(:read).and_return sp_yaml
      mock
    end

    before do
      allow(Rails.root).to receive(:join).and_call_original
      allow(Rails.root).to receive(:join).with(
        'config',
        'service_providers.yml',
      ).and_return(mock_yaml_file)
    end

    context 'with an instance-specific service_providers.yml file' do
      let(:sp_yaml) do
        <<~"SP_YAML"
          production:
            'urn:gov:gsa:openidconnect.profiles:sp:sso:gsa:dashboard':
              friendly_name: 'Review App Dashboard Instance'
              agency: 'GSA'
              agency_id: 2
              logo: '18f.svg'
              certs:
                - 'saml_test_sp'
              return_to_sp_url: 'https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov/'
              redirect_uris:
                - 'https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov/auth/logindotgov/callback'
                - 'https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov'
              push_notification_url: 'https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov/api/security_events'
        SP_YAML
      end

      it 'saves the YAML data to the database' do
        subject = described_class.new rails_env: 'production' # env has to match sample yaml key
        expect { subject.run_review_app(dashboard_url:) }.to change { ServiceProvider.count }.by 1
        new_sp = ServiceProvider.last
        expect(new_sp.friendly_name).to eq('Review App Dashboard Instance')
        expect(new_sp.return_to_sp_url).to eq("https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov/")
        expect(new_sp.certs).to eq(
          [
            Rails.root.join('certs', 'sp', 'saml_test_sp.crt').read,
          ],
        )
      end
    end

    context 'without an instance-specific service_providers.yml file' do
      let(:sp_yaml) do
        <<~SP_YAML
          production:
            'urn:gov:gsa:openidconnect.profiles:sp:sso:gsa:dashboard':
            friendly_name: 'Invalid Dashboard Review App'
            agency: 'GSA'
            agency_id: 2
            logo: '18f.svg'
            certs:
            - 'saml_test_sp'
            return_to_sp_url: 'https://INVALID-dashboard.reviewapps.identitysandbox.gov/'
            redirect_uris:
            - 'https://INVALID-dashboard.reviewapps.identitysandbox.gov/auth/logindotgov/callback'
            - 'https://INVALID-dashboard.reviewapps.identitysandbox.gov'
            push_notification_url: 'https://INVALID-dashboard.reviewapps.identitysandbox.gov/api/security_events'
        SP_YAML
      end

      it 'ignores the YAML data and uses defaults' do
        subject = described_class.new rails_env: 'production' # env has to match sample yaml key
        expect { subject.run_review_app(dashboard_url:) }.to change { ServiceProvider.count }.by 1
        new_sp = ServiceProvider.last
        expect(new_sp.friendly_name).to eq('Dashboard')
        expect(new_sp.return_to_sp_url).to eq("https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov")
        expect(new_sp.certs).to eq(
          [
            Rails.root.join('certs', 'sp', 'identity_dashboard_cert.crt').read,
          ],
        )
      end
    end

    context 'with a missing services_providers.yml file' do
      let(:sp_yaml) { nil }

      before do
        allow(mock_yaml_file).to receive(:exist?).and_return false
      end

      it 'uses defaults' do
        subject = described_class.new rails_env: 'production' # env has to match sample yaml key
        expect { subject.run_review_app(dashboard_url:) }.to change { ServiceProvider.count }.by 1
        new_sp = ServiceProvider.last
        expect(new_sp.friendly_name).to eq('Dashboard')
        expect(new_sp.return_to_sp_url).to eq("https://#{dashboard_review_slug}-dashboard.reviewapps.identitysandbox.gov")
        expect(new_sp.certs).to eq(
          [
            Rails.root.join('certs', 'sp', 'identity_dashboard_cert.crt').read,
          ],
        )
      end
    end
  end
end
