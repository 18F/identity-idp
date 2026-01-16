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

    it 'updates the plural certs column with the PEM content of certs' do
      cert_names = ['saml_test_sp', 'saml_test_sp2']
      pems = cert_names.map { |cert| Rails.root.join('certs', 'sp', "#{cert}.crt").read }

      run

      sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
      expect(sp.certs).to eq(pems)
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
