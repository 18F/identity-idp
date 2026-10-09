require 'rails_helper'

RSpec.describe 'OpenID Connect UserInfo controller' do
  describe 'show endpoint' do
    it 'does not include IDP session cookie' do
      access_token = SecureRandom.hex
      identity = create(
        :service_provider_identity,
        rails_session_id: SecureRandom.hex,
        access_token: access_token,
        user: create(:user),
      )
      authorization_header = "Bearer #{access_token}"
      OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      get api_openid_connect_userinfo_path,
          headers: { 'HTTP_AUTHORIZATION' => authorization_header }
      expect(response.headers['Set-Cookie']).to_not include(APPLICATION_SESSION_COOKIE_KEY)
    end

    it 'returns error with blank Bearer Token' do
      identity = create(
        :service_provider_identity,
        rails_session_id: SecureRandom.hex,
        access_token: nil,
        user: create(:user),
      )
      authorization_header = 'Bearer'
      OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      get api_openid_connect_userinfo_path,
          headers: { 'HTTP_AUTHORIZATION' => authorization_header }
      expect(response).to be_unauthorized
    end

    describe 'a bearer token of a confidential client' do
      let(:access_token) { SecureRandom.hex }
      let(:identity) do
        create(
          :service_provider_identity,
          rails_session_id: SecureRandom.hex,
          access_token:,
          user: create(:user),
          scope: 'openid email',
          last_authenticated_at: Time.zone.now,
        )
      end

      before do
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      end

      it 'is answered exactly as before: no challenge, the same body, any DPoP header ignored' do
        get api_openid_connect_userinfo_path,
            headers: { 'HTTP_AUTHORIZATION' => "Bearer #{access_token}" }
        expected_body = response.body

        expect(response).to have_http_status(:ok)
        expect(response.headers).not_to have_key('WWW-Authenticate')
        expect(response.media_type).to eq('application/json')
        body = JSON.parse(expected_body, symbolize_names: true)
        expect(body).to include(sub: identity.uuid, email_verified: true)
        expect(body).to have_key(:email)

        get api_openid_connect_userinfo_path,
            headers: {
              'HTTP_AUTHORIZATION' => "Bearer #{access_token}",
              'DPoP' => 'not-even-a-jwt',
            }
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_body)
        expect(response.headers).not_to have_key('WWW-Authenticate')
      end

      it 'keeps the existing error body and no challenge for an unknown bearer token' do
        get api_openid_connect_userinfo_path,
            headers: { 'HTTP_AUTHORIZATION' => 'Bearer not-a-token' }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers).not_to have_key('WWW-Authenticate')
        expect(response.body)
          .to eq({ error: t('openid_connect.user_info.errors.not_found') }.to_json)
      end

      it 'refuses the DPoP scheme for a token that is not bound' do
        get api_openid_connect_userinfo_path,
            headers: {
              'HTTP_AUTHORIZATION' => "DPoP #{access_token}",
              'DPoP' => build_dpop_proof(
                url: api_openid_connect_userinfo_url, method: 'GET', access_token:,
              ),
            }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate'])
          .to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        expect(response.body)
          .to eq({ error: t('openid_connect.user_info.errors.token_not_bound') }.to_json)
      end
    end

    describe 'a token bound to a public client key' do
      let(:access_token) { SecureRandom.hex }
      let(:identity) do
        create(
          :service_provider_identity,
          rails_session_id: SecureRandom.hex,
          access_token:,
          user: create(:user),
          scope: 'openid email',
          dpop_jkt: dpop_thumbprint,
          last_authenticated_at: Time.zone.now,
        )
      end

      before do
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      end

      def userinfo(authorization:, proof:)
        get api_openid_connect_userinfo_path,
            headers: { 'HTTP_AUTHORIZATION' => authorization, 'DPoP' => proof }.compact
      end

      it 'answers under the DPoP scheme with a proof for GET on this URL from the bound key' do
        userinfo(
          authorization: "DPoP #{access_token}",
          proof: build_dpop_proof(
            url: api_openid_connect_userinfo_url, method: 'GET', access_token:,
          ),
        )

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['sub']).to eq(identity.uuid)
        expect(response.headers).not_to have_key('WWW-Authenticate')
      end

      it 'refuses the token as a bearer token' do
        userinfo(authorization: "Bearer #{access_token}", proof: nil)

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate'])
          .to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        expect(JSON.parse(response.body)['error'])
          .to eq(t('openid_connect.user_info.errors.bound_token_requires_dpop'))
      end

      it 'refuses the DPoP scheme without a proof' do
        userinfo(authorization: "DPoP #{access_token}", proof: nil)

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate'])
          .to eq('DPoP algs="ES256 RS256", error="invalid_dpop_proof"')
        expect(JSON.parse(response.body)['error'])
          .to eq(t('openid_connect.token.errors.dpop_proof_required'))
      end

      it 'refuses a proof from another key, for another URL, or without ath' do
        [
          build_dpop_proof(
            url: api_openid_connect_userinfo_url, method: 'GET', access_token:,
            key: OpenSSL::PKey::EC.generate('prime256v1')
          ),
          build_dpop_proof(url: api_openid_connect_token_url, method: 'GET', access_token:),
          build_dpop_proof(url: api_openid_connect_userinfo_url, method: 'GET'),
        ].each do |proof|
          userinfo(authorization: "DPoP #{access_token}", proof:)
          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['WWW-Authenticate'])
            .to eq('DPoP algs="ES256 RS256", error="invalid_dpop_proof"')
        end
      end

      it 'refuses a replayed proof' do
        proof = build_dpop_proof(
          url: api_openid_connect_userinfo_url, method: 'GET', access_token:,
        )
        userinfo(authorization: "DPoP #{access_token}", proof:)
        expect(response).to have_http_status(:ok)
        userinfo(authorization: "DPoP #{access_token}", proof:)
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error'])
          .to eq(t('openid_connect.token.errors.dpop_proof_replayed'))
      end

      it 'logs the sign-in as before, naming the client' do
        stub_request_analytics
        userinfo(
          authorization: "DPoP #{access_token}",
          proof: build_dpop_proof(
            url: api_openid_connect_userinfo_url, method: 'GET', access_token:,
          ),
        )
        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          success: true, client_id: identity.service_provider, ial: identity.ial,
        )
      end

      it 'refuses a delegated token, never a sign-in credential, with or without a proof' do
        plaintext = TokenExchangeToken.generate_token
        token = create(:token_exchange_token, :key_bound, dpop_jkt: dpop_thumbprint, plaintext:)
        expect(DelegatedTokenStore.read(plaintext)).to be_present

        get api_openid_connect_userinfo_path,
            headers: { 'HTTP_AUTHORIZATION' => "Bearer #{plaintext}" }
        expect(response).to be_unauthorized

        get api_openid_connect_userinfo_path,
            headers: {
              'HTTP_AUTHORIZATION' => "DPoP #{plaintext}",
              'DPoP' => build_dpop_proof(
                url: api_openid_connect_userinfo_url, method: 'GET', access_token: plaintext,
              ),
            }
        expect(response).to be_unauthorized
        expect(JSON.parse(response.body)['error'])
          .to eq(t('openid_connect.user_info.errors.not_found'))
        DelegatedTokenStore.revoke_grant(token.grant_id)
      end
    end
  end
end
