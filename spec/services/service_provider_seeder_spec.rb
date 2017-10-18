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

      it 'only adds/updates configs for that environment' do
        run

        expect(ServiceProvider.find_by(issuer: 'urn:gov:dhs.cbp.jobs:openidconnect:aws-cbp-ttp')).
          to be

        expect(ServiceProvider.find_by(issuer: 'urn:gov:dhs.cbp.jobs:openidconnect:cert')).
          to eq(nil)
      end
    end
  end
end
