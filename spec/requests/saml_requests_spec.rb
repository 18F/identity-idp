require 'rails_helper'

RSpec.describe 'SAML requests', type: :request do
  include SamlAuthHelper

  describe 'POST /api/saml/auth' do
    let(:cookie_regex) { /\A(?<cookie>\w+)=/ }

    it 'does not set a session cookie' do
      post saml_settings.idp_sso_target_url
      new_cookies = response.header['Set-Cookie'].split("\n").map do |c|
        cookie_regex.match(c)[:cookie]
      end

      expect(new_cookies).not_to include('_identity_idp_session')
    end
  end

  describe '/api/saml/remotelogout' do
    let(:remote_slo_url) do
      saml_settings.idp_slo_target_url.gsub('logout', 'remotelogout')
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
  end
end
