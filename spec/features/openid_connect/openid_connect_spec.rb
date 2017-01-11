require 'rails_helper'

feature 'OpenID Connect' do
  context 'happy path' do
    it 'renders an authorization that redirects' do
      client_id = 'urn:gov:gsa:openidconnect:test'
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
    end
  end
end
