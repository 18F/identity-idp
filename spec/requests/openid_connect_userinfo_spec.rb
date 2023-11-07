require 'rails_helper'

RSpec.describe 'OpenID Connect UserInfo controller' do
  describe 'show endpoint' do
    it 'does not include IDP session cookie' do
      access_token = SecureRandom.hex
      identity = create(
        :service_provider_identity,
        rails_session_id: SecureRandom.hex,
        access_token:,
        user: create(:user),
      )
      authorization_header = "Bearer #{access_token}"
      OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii({}, 50)
      get api_openid_connect_userinfo_path,
          headers: { 'HTTP_AUTHORIZATION' => authorization_header }
      expect(response.headers['Set-Cookie']).to_not include(APPLICATION_SESSION_COOKIE_KEY)
    end
  end
end
