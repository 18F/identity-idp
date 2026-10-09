require 'rails_helper'

RSpec.describe DelegatedAccessSeeder do
  subject(:seeder) { described_class.new(deploy_env: deploy_env) }
  let(:deploy_env) { 'dev' }
  let(:sp_issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra_sts' }
  let(:oidc_issuer) { 'urn:gov:gsa:openidconnect:sp:records_agency' }
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

    it 'registers the service provider as a public client with no signing certificate' do
      seeder.run

      sp = ServiceProvider.find_by(issuer: sp_issuer)
      expect(sp.pkce).to eq(true)
      expect(sp.certs).to be_blank
    end

    it 'loads the applications with their scope values, content and API URLs' do
      seeder.run

      housing = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:records_agency')
      expect(housing.delegation_application?).to eq(true)
      expect(housing.delegation_scope).to eq('token_exchange:housing_records')
      expect(housing.delegation_read_write?).to eq(true)
      expect(housing.accepts_delegation_from?(sp_issuer)).to eq(true)
      expect(housing.attribute_bundle).to eq(%w[email])
      expect(housing.delegation_sp_shareable_attributes).to eq([])
      records_api = housing.token_exchange_resource_servers.first
      expect(records_api.identifier).to eq('https://records-api.agency.localdev')
      expect(records_api.max_access_token_seconds).to eq(300)
      expect(records_api.max_family_seconds).to eq(14400)

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
      stub_const(
        'ENV',
        ENV.to_h.merge(
          'DELEGATION_SP_URL' => 'https://mybenefits.example.gov',
          'DELEGATION_OIDC_AGENCY_URL' => 'https://records.housing.example.gov',
          'DELEGATION_SAML_AGENCY_URL' => 'https://portal.retirement.example.gov',
        ),
      )
      seeder.run

      sp = ServiceProvider.find_by(issuer: sp_issuer)
      expect(sp.return_to_sp_url).to eq('https://mybenefits.example.gov')
      expect(sp.redirect_uris).to include('https://mybenefits.example.gov/auth/result')
      expect(Agency.find(100).delegation_learn_more_url)
        .to eq('https://mybenefits.example.gov/about')

      housing = ServiceProvider.find_by(issuer: oidc_issuer)
      expect(housing.redirect_uris).to include('https://records.housing.example.gov/auth/result')
      expect(Agency.find(101).delegation_learn_more_url)
        .to eq('https://records.housing.example.gov/')

      retirement = ServiceProvider.find_by(issuer: saml_issuer)
      expect(retirement.acs_url).to eq('https://portal.retirement.example.gov/consume')
      expect(Agency.find(102).delegation_learn_more_url)
        .to eq('https://portal.retirement.example.gov/')

      # The API identifiers are RFC 8707 resource indicators, not hostnames, so they do not move.
      expect(TokenExchangeResourceServer.pluck(:identifier)).to contain_exactly(
        'https://records-api.agency.localdev', 'https://benefits-api.agency.localdev'
      )
    end

    # What the reference applications and the end-to-end harness read from this file: a change
    # here is a change to them.
    describe 'the contract with the reference applications' do
      before { seeder.run }

      it 'registers the service provider the browser client identifies itself as' do
        sp = ServiceProvider.find_by(issuer: sp_issuer)
        expect(sp.friendly_name).to eq('MyBenefits Assistant')
        expect(sp.agency.name).to eq('Office of Benefits Coordination')
        expect(sp.ial).to eq(2)
        expect(sp.pkce).to eq(true)
        expect(sp.certs).to be_blank
        expect(sp.token_exchange_enabled_sp).to eq(true)
        expect(sp.redirect_uris).to contain_exactly(
          'http://localhost:9292/', 'http://localhost:9292/auth/result',
          'http://localhost:9292/logout'
        )
      end

      it 'registers the OAuth agency application the browser client exchanges for' do
        housing = ServiceProvider.find_by(issuer: oidc_issuer)
        expect(housing.friendly_name).to eq('Housing Assistance Records')
        expect(housing.agency.name).to eq('Department of Housing Support')
        expect(housing.agency).not_to eq(ServiceProvider.find_by(issuer: sp_issuer).agency)
        expect(housing.delegation_scope).to eq('token_exchange:housing_records')
        expect(housing.allowed_delegation_service_providers).to eq([])
        expect(housing.redirect_uris).to include('http://localhost:9393/auth/result')

        records_api = housing.token_exchange_resource_servers.sole
        expect(records_api.identifier).to eq('https://records-api.agency.localdev')
        expect(records_api.token_format).to eq('oauth')
        expect(records_api.active).to eq(true)
      end

      it 'registers the SAML agency application the browser client exchanges for' do
        retirement = ServiceProvider.find_by(issuer: saml_issuer)
        expect(retirement.friendly_name).to eq('Retirement Benefits Portal')
        expect(retirement.agency.name).to eq('National Retirement Administration')
        expect(retirement.delegation_scope).to eq('token_exchange:retirement_benefits')
        expect(retirement.allowed_delegation_service_providers).to eq([sp_issuer])
        expect(retirement.acs_url).to eq('http://localhost:4567/consume')

        benefits_api = retirement.token_exchange_resource_servers.sole
        expect(benefits_api.identifier).to eq('https://benefits-api.agency.localdev')
        expect(benefits_api.token_format).to eq('saml2')
        expect(benefits_api.active).to eq(true)
      end

      it 'carries no per-API key-binding setting: binding follows the client type' do
        fixture = Rails.root.join(DelegatedAccessSeeder::DEFAULT_YAML_PATH).read
        expect(fixture).not_to include('dpop_required')
      end

      it 'gives the service provider no Attempts API credentials' do
        fixture = YAML.safe_load(
          ERB.new(Rails.root.join(DelegatedAccessSeeder::DEFAULT_YAML_PATH).read).result,
        )
        expect(fixture.dig('service_providers', sp_issuer).keys.grep(/attempts/)).to be_empty
      end
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
