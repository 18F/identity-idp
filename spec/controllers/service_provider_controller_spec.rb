require 'rails_helper'

describe ServiceProviderController do
  include SamlAuthHelper

  describe '#update' do
    let(:dashboard_sp_issuer) { 'some-dashboard-service-provider' }
    let(:dashboard_service_providers) do
      [
        {
          issuer: dashboard_sp_issuer,
          agency: 'a service provider',
          friendly_name: 'a friendly service provider',
          description: 'user friendly login.gov dashboard',
          acs_url: 'http://sp.example.org/saml/login',
          assertion_consumer_logout_service_url: 'http://sp.example.org/saml/logout',
          block_encryption: 'aes256-cbc',
          cert: saml_test_sp_cert,
          active: true
        }
      ]
    end

    context 'feature on' do
      before do
        allow(Figaro.env).to receive(:use_dashboard_service_providers).and_return('true')
        allow_any_instance_of(ServiceProviderUpdater).to receive(:dashboard_service_providers).
          and_return(dashboard_service_providers)
        SERVICE_PROVIDERS.delete dashboard_sp_issuer
        VALID_SERVICE_PROVIDERS.delete dashboard_sp_issuer
      end

      after do
        SERVICE_PROVIDERS.delete dashboard_sp_issuer
        VALID_SERVICE_PROVIDERS.delete dashboard_sp_issuer
      end

      it 'returns 200' do
        post :update

        expect(response.status).to eq 200
      end

      it 'updates SERVICE_PROVIDERS' do
        expect(SERVICE_PROVIDERS[dashboard_sp_issuer]).to eq nil

        post :update

        sp = ServiceProvider.new(dashboard_sp_issuer)

        expect(sp.metadata[:agency]).to eq dashboard_service_providers.first[:agency]
        expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
        expect(sp.valid?).to eq true
        expect(VALID_SERVICE_PROVIDERS).to include dashboard_sp_issuer
      end

      context 'with CSRF protection enabled' do
        before do
          ActionController::Base.allow_forgery_protection = true
        end

        after do
          ActionController::Base.allow_forgery_protection = false
        end

        it 'does not redirect after invalid CSRF token' do
          post :update

          expect(response.status).to_not eq(302)
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
