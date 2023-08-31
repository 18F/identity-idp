require 'rails_helper'

RSpec.describe ServiceProviderController do
  include SamlAuthHelper

  describe '#update' do
    let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
    let(:agency) { create(:agency) }
    let(:attributes) do
      {
        issuer: dashboard_sp_issuer,
        agency_id: agency.id,
        friendly_name: 'a friendly service provider',
        description: 'user friendly Login.gov dashboard',
        acs_url: 'http://sp.example.org/saml/login',
        assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
        block_encryption: 'aes256-cbc',
        certs: [saml_test_sp_cert],
        active: true,
      }
    end
    let(:dashboard_service_providers) { [attributes] }
    let(:token) { '123ABC' }
    let(:use_feature) { true }

    before do
      headers(token)
      allow(IdentityConfig.store).to receive(:use_dashboard_service_providers) { use_feature }
    end

    context 'feature on, correct token in headers' do
      context 'with no body' do
        before do
          allow_any_instance_of(ServiceProviderUpdater).to receive(:dashboard_service_providers).
            and_return(dashboard_service_providers)
          post :update
        end

        after do
          ServiceProvider.find_by(issuer: dashboard_sp_issuer)&.destroy
        end

        it 'returns 200' do
          expect(response.status).to eq 200
        end

        it 'updates the matching ServiceProvider in the DB' do
          sp = ServiceProvider.find_by(issuer: dashboard_sp_issuer)

          expect(sp.metadata[:agency]).to eq dashboard_service_providers.first[:agency]
          expect(sp.ssl_certs.first).to be_a OpenSSL::X509::Certificate
          expect(sp.active?).to eq true
        end

        context 'with CSRF protection enabled' do
          before do
            ActionController::Base.allow_forgery_protection = true
          end

          after do
            ActionController::Base.allow_forgery_protection = false
          end

          it 'ignores invalid CSRF tokens' do
            expect(response.status).to eq(200)
          end
        end
      end

      context 'with a service provider passed in via a request body' do
        describe 'with the req Content-Type set to "gzip/json"' do
          let(:friendly_name) { 'A new friendly name' }
          let(:body) do
            Zlib.gzip({ service_provider: attributes.merge(friendly_name:) }.to_json)
          end

          before do
            # Rails controller tests will fail unless the Content-Type is registered
            # Not needed in production
            Mime::Type.register 'gzip/json', :gzip_json
            request.headers['Content-Type'] = 'gzip/json'
            post :update, body:
          end

          after do
            Mime::Type.unregister :gzip_json
          end

          it 'returns 200' do
            expect(response.status).to eq 200
          end

          it 'updates the matching ServiceProvider in the DB' do
            sp = ServiceProvider.find_by(issuer: dashboard_sp_issuer)

            expect(sp.agency).to eq agency
            expect(sp.friendly_name).to eq friendly_name
            expect(sp.active?).to eq true
          end
        end

        describe 'with a different Content-Type' do
          let(:friendly_name) { 'A new friendly name' }
          let(:params) { { service_provider: attributes.merge(friendly_name:) } }

          before do
            request.headers['Content-Type'] = 'application/json'
            post :update, params:
          end

          it 'returns 200' do
            expect(response.status).to eq 200
          end

          it 'updates the matching ServiceProvider in the DB' do
            sp = ServiceProvider.find_by(issuer: dashboard_sp_issuer)

            expect(sp.agency).to eq agency
            expect(sp.friendly_name).to eq friendly_name
            expect(sp.active?).to eq true
          end
        end
      end
    end

    context 'incorrect token in header' do
      let(:token) { 'BAD' }

      it 'returns a 401' do
        post :update

        expect(response.status).to eq 401
      end
    end

    context 'missing token in header' do
      let(:token) { nil }

      it 'returns a 401' do
        post :update

        expect(response.status).to eq 401
      end
    end

    context 'feature off' do
      let(:use_feature) { false }
      before { post :update }

      it 'returns 200' do
        expect(response.status).to eq 200
      end

      it 'returns the body' do
        body = { status: 'Service providers updater has not been enabled.' }.to_json
        expect(response.body).to eq body
      end
    end

    def headers(token)
      request.headers['X-LOGIN-DASHBOARD-TOKEN'] = token
    end
  end
end
