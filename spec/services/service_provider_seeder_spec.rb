require 'rails_helper'

RSpec.describe ServiceProviderSeeder do
  subject(:instance) { ServiceProviderSeeder.new(rails_env: rails_env, deploy_env: deploy_env) }
  let(:rails_env) { 'test' }
  let(:deploy_env) { 'int' }

  describe '#run' do
    before { ServiceProvider.delete_all }

    subject(:run) { instance.run }

    it 'inserts service providers into the database from service_providers.yml' do
      expect { run }.to change { ServiceProvider.count }
    end

    context 'with other existing service providers in the database' do
      let!(:existing_provider) { create(:service_provider) }

      it 'sets approved, active and native on service providers from the yaml' do
        run

        config_sp = ServiceProvider.from_issuer('http://test.host')
        expect(config_sp.approved).to eq(true)
        expect(config_sp.active).to eq(true)
        expect(config_sp.native).to eq(true)
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
          acs_url: 'http://test.host/test/saml/decode_assertion_old'
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
          expect(ServiceProvider.find_by(issuer: 'urn:gov:dhs.cbp.jobs:openidconnect:aws-cbp-ttp')).
            to be_present

          # restrict_to_deploy_env: staging
          expect(ServiceProvider.find_by(issuer: 'urn:gov:dhs.cbp.jobs:openidconnect:cert')).
            to eq(nil)

          # restrict_to_deploy_env: nil
          expect(ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:sinatra')).
            to eq(nil)
        end
      end

      context 'in another environment' do
        let(:deploy_env) { 'staging' }

        it 'only writes configs with restrict_to_deploy_env for that env, or no restrictions' do
          run

          # restrict_to_deploy_env: prod
          expect(ServiceProvider.find_by(issuer: 'urn:gov:dhs.cbp.jobs:openidconnect:aws-cbp-ttp')).
            to eq(nil)

          # restrict_to_deploy_env: staging
          expect(ServiceProvider.find_by(issuer: 'urn:gov:dhs.cbp.jobs:openidconnect:cert')).
            to be_present

          # restrict_to_deploy_env: nil
          expect(ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:sinatra')).
            to be_present
        end
      end
    end
  end
end
