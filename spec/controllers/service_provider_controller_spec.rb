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

    context 'feature on, correct token in headers' do
      before do
        correct_token = '123ABC'
        headers(correct_token)
        allow(IdentityConfig.store).to receive(:use_dashboard_service_providers).and_return(true)
      end

      context 'with no params' do
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

      context 'with a service provider passed via params' do
        let(:friendly_name) { 'A new friendly name' }
        let(:params) do
          {
            service_provider: attributes.merge(friendly_name:),
          }
        end

        before do
          request.content_type = 'gzip/json'
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

    context 'incorrect token in header' do
      before do
        incorrect_token = 'BAD'
        headers(incorrect_token)
      end

      it 'returns a 401' do
        post :update

        expect(response.status).to eq 401
      end
    end

    def headers(token)
      request.headers['X-LOGIN-DASHBOARD-TOKEN'] = token
    end
  end
end
