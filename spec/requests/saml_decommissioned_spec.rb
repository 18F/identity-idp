require 'rails_helper'

RSpec.describe 'SAML decommissioned endpoint', type: :request do
  include SamlAuthHelper

  let(:decommissioned_year) { '2024' }
  let(:live_year) { SamlAuthHelper::PATH_YEAR }

  let!(:service_provider) do
    create(
      :service_provider,
      issuer: 'my.first.issuer.gov',
      friendly_name: 'My Partner',
      return_to_sp_url: 'https://my.first.issuer.gov/home',
      active: true,
    )
  end

  let(:saml_overrides) do
    {
      issuer: service_provider.issuer,
      idp_sso_target_url: api_saml_auth_url(path_year: live_year),
    }
  end

  describe 'GET /api/saml/auth2024' do
    it 'renders the decommissioned page naming the service provider' do
      get "/api/saml/auth#{decommissioned_year}",
          params: UriService.params(saml_authn_request_url(overrides: saml_overrides))

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Decommissioned Access')
      expect(response.body).to include('My Partner')
    end

    it 'links to the return_to_sp_url on file for the service provider' do
      get "/api/saml/auth#{decommissioned_year}",
          params: UriService.params(saml_authn_request_url(overrides: saml_overrides))

      expect(response.body).to include('https://my.first.issuer.gov/home')
    end

    it 'decodes a POST-binding (non-deflated) SAMLRequest' do
      post_params = authn_request_post_params(saml_settings(overrides: saml_overrides))

      get "/api/saml/auth#{decommissioned_year}",
          params: { SAMLRequest: post_params['SAMLRequest'] }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('My Partner')
    end

    context 'without a SAMLRequest' do
      it 'renders generic copy' do
        get "/api/saml/auth#{decommissioned_year}"

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('this service provider')
        expect(response.body).to_not include('My Partner')
      end
    end

    context 'with a malformed SAMLRequest' do
      it 'renders generic copy' do
        get "/api/saml/auth#{decommissioned_year}", params: { SAMLRequest: 'not-base64-$$$' }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('this service provider')
      end
    end

    context 'with an issuer that has no service provider' do
      let(:saml_overrides) do
        {
          issuer: 'no.such.issuer.gov',
          idp_sso_target_url: api_saml_auth_url(path_year: live_year),
        }
      end

      it 'renders generic copy' do
        get "/api/saml/auth#{decommissioned_year}",
            params: UriService.params(saml_authn_request_url(overrides: saml_overrides))

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('this service provider')
        expect(response.body).to_not include('My Partner')
      end
    end
  end

  describe 'other decommissioned-year SAML paths' do
    it 'renders the decommissioned page for metadata' do
      get "/api/saml/metadata#{decommissioned_year}"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Decommissioned Access')
    end

    it 'renders the decommissioned page for logout' do
      get "/api/saml/logout#{decommissioned_year}"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Decommissioned Access')
    end
  end

  describe 'live SAML routes' do
    it 'does not shadow auth for a live year' do
      get api_saml_auth_url(path_year: live_year),
          params: UriService.params(saml_authn_request_url)

      expect(response.body).to_not include('Decommissioned Access')
      expect(response).to be_redirect
    end

    it 'does not shadow metadata for a live year' do
      get api_saml_metadata_url(path_year: live_year)

      expect(response).to be_ok
      expect(response.body).to_not include('Decommissioned Access')
    end

    it 'does not shadow /api/saml/complete' do
      expect(Rails.application.routes.recognize_path('/api/saml/complete', method: :get))
        .to include(controller: 'saml_completion', action: 'index')
    end
  end
end
