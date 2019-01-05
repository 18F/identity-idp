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
          active: true,
        },
      ]
    end

    context 'feature on, correct token in headers' do
      before do
        correct_token = '123ABC'
        headers(correct_token)
        allow(Figaro.env).to receive(:use_dashboard_service_providers).and_return('true')
        allow_any_instance_of(ServiceProviderUpdater).to receive(:dashboard_service_providers).
          and_return(dashboard_service_providers)
      end

      after do
        ServiceProvider.from_issuer(dashboard_sp_issuer).destroy
      end

      it 'returns 200' do
        post :update

        expect(response.status).to eq 200
      end

      it 'updates the matching ServiceProvider in the DB' do
        post :update

        sp = ServiceProvider.from_issuer(dashboard_sp_issuer)

        expect(sp.metadata[:agency]).to eq dashboard_service_providers.first[:agency]
        expect(sp.ssl_cert).to be_a OpenSSL::X509::Certificate
        expect(sp.active?).to eq true
      end

      context 'with CSRF protection enabled' do
        before do
          correct_token = '123ABC'
          headers(correct_token)
          ActionController::Base.allow_forgery_protection = true
        end

        after do
          ActionController::Base.allow_forgery_protection = false
        end

        it 'ignores invalid CSRF tokens' do
          post :update

          expect(response.status).to eq(200)
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
