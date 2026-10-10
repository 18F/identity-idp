require 'rails_helper'

RSpec.describe DelegatedAccessSeeder do
  subject(:seeder) do
    described_class.new(rails_env: rails_env, deploy_env: deploy_env, yaml_path: yaml_path)
  end
  let(:rails_env) { 'development' }
  let(:deploy_env) { 'dev' }
  let(:yaml_path) { fixture_path }
  let(:fixture_path) { 'config/delegated_access.localdev.yml' }
  let(:sp_issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra_sts' }
  let(:oidc_issuer) { 'urn:gov:gsa:openidconnect:sp:records_agency' }
  let(:saml_issuer) { 'urn:gov:gsa:SAML:2.0.profiles:sp:sso:benefits_agency' }

  def fixture_data
    YAML.safe_load(ERB.new(Rails.root.join(fixture_path).read).result)
  end

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

      sp = ServiceProvider.find_by(issuer: sp_issuer)
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

      housing = ServiceProvider.find_by(issuer: oidc_issuer)
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
        expect(Rails.root.join(fixture_path).read).not_to include('dpop_required')
      end

      it 'gives the service provider no Attempts API credentials' do
        sp_config = fixture_data.dig('development', 'service_providers', sp_issuer)
        expect(sp_config.keys.grep(/attempts/)).to be_empty
      end

      it 'offers a sandbox the same entries, each restricted to sandbox deploy environments' do
        development = fixture_data.fetch('development')
        production = fixture_data.fetch('production')
        strip = ->(entries) { entries.transform_values { |e| e.except('restrict_to_deploy_env') } }

        %w[agencies service_providers].each do |section|
          expect(production.fetch(section).values.map { |e| e['restrict_to_deploy_env'] })
            .to all(eq('sandbox'))
          expect(strip.call(production.fetch(section))).to eq(development.fetch(section))
        end
      end
    end

    context 'when the file is absent' do
      let(:yaml_path) { 'config/no_such_delegated_access.yml' }

      it 'seeds nothing and raises nothing' do
        expect { seeder.run }.not_to raise_error
        expect(Agency.where(id: [100, 101, 102])).to be_empty
        expect(ServiceProvider.find_by(issuer: sp_issuer)).to be_nil
      end
    end

    context 'when the file is a symlink to nothing' do
      let(:yaml_path) { File.join(Dir.mktmpdir, 'delegated_access.yml') }

      before { File.symlink('delegated_access.localdev.yml', yaml_path) }
      after { FileUtils.rm_rf(File.dirname(yaml_path)) }

      it 'seeds nothing and raises nothing' do
        expect(File.symlink?(yaml_path)).to eq(true)
        expect { seeder.run }.not_to raise_error
        expect(ServiceProvider.find_by(issuer: sp_issuer)).to be_nil
      end
    end

    context 'when the file has no section for the Rails environment' do
      let(:rails_env) { 'test' }

      it 'seeds nothing' do
        expect { seeder.run }.not_to raise_error
        expect(ServiceProvider.find_by(issuer: sp_issuer)).to be_nil
      end
    end

    context 'in RAILS_ENV=production' do
      let(:rails_env) { 'production' }

      context 'in a sandbox deploy environment' do
        let(:deploy_env) { 'dev' }

        it 'writes the production entries, which are restricted to sandbox' do
          seeder.run

          expect(Agency.where(id: [100, 101, 102]).count).to eq(3)
          expect(ServiceProvider.find_by(issuer: sp_issuer).token_exchange_enabled_sp).to eq(true)
          expect(ServiceProvider.where(delegation_application: true).pluck(:issuer))
            .to contain_exactly(oidc_issuer, saml_issuer)
        end
      end

      %w[prod staging].each do |restricted|
        context "in #{restricted}" do
          let(:deploy_env) { restricted }

          it 'writes none of the fictitious entries' do
            seeder.run

            expect(Agency.where(id: [100, 101, 102])).to be_empty
            expect(ServiceProvider.where(issuer: [sp_issuer, oidc_issuer, saml_issuer])).to be_empty
            expect(TokenExchangeResourceServer.count).to eq(0)
          end
        end
      end
    end

    describe 'restrict_to_deploy_env on an agency' do
      let(:rails_env) { 'production' }
      let(:yaml_path) { File.join(Dir.mktmpdir, 'delegated_access.yml') }

      before do
        File.write(yaml_path, <<~YAML)
          production:
            agencies:
              900:
                name: 'Prod Only Agency'
                abbreviation: 'POA'
                restrict_to_deploy_env: 'prod'
              901:
                name: 'Staging Only Agency'
                abbreviation: 'SOA'
                restrict_to_deploy_env: 'staging'
              902:
                name: 'Everywhere But Prod Agency'
                abbreviation: 'EBP'
        YAML
      end
      after { FileUtils.rm_rf(File.dirname(yaml_path)) }

      context 'in prod' do
        let(:deploy_env) { 'prod' }

        it 'writes only the entry restricted to prod, without the restriction as an attribute' do
          seeder.run

          expect(Agency.where(id: [900, 901, 902]).pluck(:id)).to eq([900])
          expect(Agency.find(900).attributes).not_to have_key('restrict_to_deploy_env')
          expect(Agency.find(900).name).to eq('Prod Only Agency')
        end
      end

      context 'in staging' do
        let(:deploy_env) { 'staging' }

        it 'writes the staging entry and the unrestricted one' do
          seeder.run

          expect(Agency.where(id: [900, 901, 902]).pluck(:id)).to contain_exactly(901, 902)
        end
      end

      context 'in a sandbox' do
        let(:deploy_env) { 'int' }

        it 'writes only the unrestricted entry' do
          seeder.run

          expect(Agency.where(id: [900, 901, 902]).pluck(:id)).to eq([902])
        end
      end
    end
  end
end
