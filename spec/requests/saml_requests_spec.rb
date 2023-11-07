require 'rails_helper'

RSpec.describe 'SAML requests', type: :request do
  include SamlAuthHelper

  describe 'GET /api/saml/auth' do
    let(:path_year) { SamlAuthHelper::PATH_YEAR }

    it 'is successful' do
      get api_saml_auth_url(path_year:),
          params: UriService.params(saml_authn_request_url)

      expect(response).to be_redirect
    end

    context 'for an unsupported year' do
      let(:path_year) { (SamlEndpoint.suffixes.max.to_i + 1).to_s }

      it '404s' do
        get api_saml_auth_url(path_year:)

        expect(response).to be_not_found
      end
    end
  end

  describe 'POST /api/saml/auth' do
    let(:cookie_regex) { /\A(?<cookie>\w+)=/ }

    it 'renders a form for the SAML year that was requested' do
      path_year = '2022'

      overridden_saml_settings = saml_settings(
        overrides: {
          idp_sso_target_url: api_saml_auth_url(path_year:),
        },
      )
      path_year = overridden_saml_settings.idp_sso_target_url[-4..-1]

      post overridden_saml_settings.idp_sso_target_url
      page = Capybara.string(response.body)
      form_action = page.find_css("form[action$=\"#{path_year}\"]").first[:action]
      expect(form_action).to be_present
    end

    it 'does not set a session cookie' do
      post saml_settings.idp_sso_target_url
      new_cookies = response.header['Set-Cookie'].split("\n").map do |c|
        cookie_regex.match(c)[:cookie]
      end

      expect(new_cookies).not_to include('_identity_idp_session')
    end

    context 'for an unsupported year' do
      let(:path_year) { (SamlEndpoint.suffixes.max.to_i + 1).to_s }

      it '404s' do
        post api_saml_auth_url(path_year:)

        expect(response).to be_not_found
      end
    end
  end

  describe '/api/saml/remotelogout' do
    let(:path_year) { SamlAuthHelper::PATH_YEAR }
    let(:remote_slo_url) do
      api_saml_remotelogout_url(path_year:)
    end

    xit 'does not accept GET requests' do
      get remote_slo_url
      expect(response.status).to eq(404)
    end

    it 'does not accept DELETE requests' do
      delete remote_slo_url
      expect(response.status).to eq(404)
    end

    it 'accepts POST requests' do
      post remote_slo_url
      # fails (:bad_request) without SAMLRequest param but not 404
      expect(response.status).to eq(400)
    end

    context 'for an unsupported year' do
      let(:path_year) { (SamlEndpoint.suffixes.max.to_i + 1).to_s }

      it '404s' do
        post api_saml_remotelogout_url(path_year:)

        expect(response).to be_not_found
      end
    end
  end
end
