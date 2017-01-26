require 'rails_helper'

feature 'OpenID Connect' do
  context 'happy path' do
    it 'renders an authorization that redirects' do
      client_id = 'urn:gov:gsa:openidconnect:test'
      service_provider = ServiceProvider.new(client_id)
      state = SecureRandom.hex
      nonce = SecureRandom.hex

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid profile',
        redirect_uri: 'gov.gsa.openidconnect.test://result',
        state: state,
        prompt: 'select_account',
        nonce: nonce
      )

      _user = sign_in_live_with_2fa

      click_button t('openid_connect.authorization.index.allow')

      redirect_uri = URI(current_url)
      redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access

      expect(redirect_uri.to_s).to start_with('gov.gsa.openidconnect.test://result')
      expect(redirect_params[:state]).to eq(state)

      code = redirect_params[:code]
      expect(code).to be_present

      page.driver.post openid_connect_token_path,
                       grant_type: 'authorization_code',
                       code: code,
                       redirect_uri: 'gov.gsa.openidconnect.test://result',
                       client_id: client_id,
                       client_secret: service_provider.metadata[:client_secret]

      token_response = JSON.parse(page.body).with_indifferent_access

      id_token = token_response[:id_token]
      expect(id_token).to be_present

      decoded_id_token, _headers = JWT.decode(
        id_token, sp_public_key, true, algorithm: 'RS256'
      ).map(&:with_indifferent_access)

      sub = decoded_id_token[:sub]
      expect(sub).to be_present
      expect(decoded_id_token[:nonce]).to eq(nonce)
      expect(decoded_id_token[:aud]).to eq(client_id)
      expect(decoded_id_token[:acr]).to eq(Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF)
      expect(decoded_id_token[:iss]).to eq(root_url)

      access_token = token_response[:access_token]
      expect(access_token).to be_present

      page.driver.get openid_connect_userinfo_path,
                      {},
                      'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

      userinfo_response = JSON.parse(page.body).with_indifferent_access
      expect(userinfo_response[:sub]).to eq(sub)
    end
  end

  def sp_public_key
    @sp_public_key ||= begin
      OpenSSL::X509::Certificate.new(File.read(Rails.root.join('certs/saml.crt'))).public_key
    end
  end
end
