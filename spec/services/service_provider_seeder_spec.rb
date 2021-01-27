require 'rails_helper'

RSpec.describe ServiceProviderSeeder do
  subject(:instance) { ServiceProviderSeeder.new(rails_env: rails_env, deploy_env: deploy_env) }
  let(:rails_env) { 'test' }
  let(:deploy_env) { 'int' }

  describe '#run' do
    before { ServiceProvider.delete_all }

    subject(:run) { instance.run }

    it 'inserts service providers into the database from service_providers.yml' do
      expect { run }.to change(ServiceProvider, :count)
    end

    context 'with other existing service providers in the database' do
      let!(:existing_provider) { create(:service_provider) }

      it 'sets approved, active and native on service providers from the yaml' do
        run

        config_sp = ServiceProvider.from_issuer('http://test.host')
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
        )
      end

      it 'updates the attributes based on the current value of the yml file' do
        expect { run }.
          to change { ServiceProvider.from_issuer('http://test.host').acs_url }.
          to('http://test.host/test/saml/decode_assertion')
      end
    end

    context 'when running in a production environment' do
      let(:rails_env) { 'production' }

      context 'in prod' do
        let(:deploy_env) { 'prod' }

        it 'only writes configs with restrict_to_deploy_env for prod' do
          run

          # restrict_to_deploy_env: prod
          expect(ServiceProvider.find_by(issuer: 'urn:gov:login:test-providers:fake-prod-sp')).
            to be_present

          # restrict_to_deploy_env: staging
          expect(ServiceProvider.find_by(issuer: 'urn:gov:login:test-providers:fake-staging-sp')).
            to eq(nil)

          # restrict_to_deploy_env: nil
          expect(
            ServiceProvider.find_by(issuer: 'urn:gov:login:test-providers:fake-unrestricted-sp'),
          ).to eq(nil)
        end

        it 'sends New Relic an error if the DB has an SP not in the config' do
          allow(NewRelic::Agent).to receive(:notice_error)
          create(:service_provider, issuer: 'missing_issuer')
          run

          expect(NewRelic::Agent).to have_received(:notice_error)
        end
      end

      context 'in the staging environment' do
        let(:deploy_env) { 'staging' }

        it 'only writes configs with restrict_to_deploy_env for that env, or no restrictions' do
          run

          # restrict_to_deploy_env: prod
          expect(ServiceProvider.find_by(issuer: 'urn:gov:login:test-providers:fake-prod-sp')).
            to eq(nil)

          # restrict_to_deploy_env: staging
          expect(ServiceProvider.find_by(issuer: 'urn:gov:login:test-providers:fake-staging-sp')).
            to be_present

          # restrict_to_deploy_env: nil
          expect(
            ServiceProvider.find_by(
              issuer: 'urn:gov:login:test-providers:fake-unrestricted-sp',
            ),
          ).to be_present
        end

        it 'sends New Relic an error if the DB has an SP not in the config' do
          allow(NewRelic::Agent).to receive(:notice_error)
          create(:service_provider, issuer: 'missing_issuer')
          run

          expect(NewRelic::Agent).to have_received(:notice_error)
        end
      end

      context 'in another environment' do
        let(:deploy_env) { 'int' }

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
              cert: 'saml_test_sp',
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
        ServiceProviderSeeder.new(rails_env: 'non-existant environment',
                                  deploy_env: 'non-existant environment')
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
end
