require 'rails_helper'

RSpec.describe DelegatedAccessSeeder do
  subject(:seeder) { described_class.new(deploy_env: deploy_env) }
  let(:deploy_env) { 'dev' }
  let(:sp_issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra_sts' }
  let(:saml_issuer) { 'urn:gov:gsa:SAML:2.0.profiles:sp:sso:benefits_agency' }

  describe '#run' do
    it 'loads the fictitious agencies with their consent content' do
      seeder.run

      housing = Agency.find(101)
      expect(housing.name).to eq('Department of Housing Support')
      expect(housing.delegation_description_for(:es))
        .to eq('ayuda a las personas a encontrar, conservar y pagar su vivienda.')
      expect(housing.delegation_learn_more_url).to eq('http://localhost:9393/')
    end

    it 'loads the service provider approved for delegation with its content' do
      seeder.run

      sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:sinatra_sts')
      expect(sp.token_exchange_enabled_sp).to eq(true)
      expect(sp.active).to eq(true)
      expect(sp.delegation_operator_legal_name).to eq('Office of Benefits Coordination')
      expect(sp.delegation_uses_ai).to eq(true)
      expect(sp.redirect_uris).to include('http://localhost:9292/auth/result')
    end

    it 'loads the applications with their scope values, content and API URLs' do
      seeder.run

      housing = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:records_agency')
      expect(housing.delegation_application?).to eq(true)
      expect(housing.delegation_scope).to eq('token_exchange:housing_records')
      expect(housing.delegation_read_write?).to eq(true)
      expect(housing.accepts_delegation_from?(sp_issuer)).to eq(true)
      records_api = housing.token_exchange_resource_servers.first
      expect(records_api.identifier).to eq('https://records-api.agency.localdev')
      expect(records_api.max_access_token_seconds).to eq(300)

      retirement = ServiceProvider.find_by(issuer: saml_issuer)
      expect(retirement.delegation_scope).to eq('token_exchange:retirement_benefits')
      expect(retirement.accepts_delegation_from?(sp_issuer)).to eq(true)
      expect(retirement.accepts_delegation_from?('urn:someone-else')).to eq(false)
      expect(retirement.token_exchange_resource_servers.first.token_format).to eq('saml2')
    end

    it 'is idempotent' do
      seeder.run
      expect { seeder.run }.not_to(
        change { [Agency.count, ServiceProvider.count, TokenExchangeResourceServer.count] },
      )
    end

    it 'reads hosts from the environment so a sandbox can point at hosted reference apps' do
      stub_const('ENV', ENV.to_h.merge('DELEGATION_SP_URL' => 'https://mybenefits.example.gov'))
      seeder.run

      sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:sinatra_sts')
      expect(sp.return_to_sp_url).to eq('https://mybenefits.example.gov')
    end

    %w[prod staging].each do |refused|
      context "in #{refused}" do
        let(:deploy_env) { refused }

        it 'refuses to run and loads nothing' do
          expect { seeder.run }.to raise_error(DelegatedAccessSeeder::RefusedEnvironment)
          expect(ServiceProvider.find_by(issuer: sp_issuer)).to be_nil
        end
      end
    end
  end
end
