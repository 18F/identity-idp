require 'rails_helper'

# Compatibility and transaction invariants for the delegated-access review stack.
RSpec.describe 'Delegated access review regressions', type: :request do
  include Rails.application.routes.url_helpers

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(false)
  end

  context 'disabled-feature compatibility' do
    let(:sp) do
      create(
        :service_provider, pkce: false, dpop_required: false,
                           redirect_uris: ['https://client.example.gov/callback']
      )
    end
    let(:authorization) do
      {
        acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
        client_id: sp.issuer,
        redirect_uri: sp.redirect_uris.first,
        response_type: 'code',
        scope: 'openid email',
        state: SecureRandom.hex,
        nonce: SecureRandom.hex,
        code_challenge: Digest::SHA256.urlsafe_base64digest('v' * 43),
        code_challenge_method: 'S256',
      }
    end

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false)
      allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(false)
    end

    [
      { dpop_jkt: 'previously-ignored' },
      { site_key_jwk: 'previously-ignored' },
      { scope: 'openid email token_exchange:previously_ignored' },
      { scope: 'openid email document_images' },
    ].product([false, nil, true]).each do |extra, pkce|
      it "preserves #{extra.keys.first}=#{extra.values.first}, pkce=#{pkce.inspect}" do
        sp.update!(pkce:)
        # Before delegated access (main 063d69fc91), these optional inputs were ignored.
        params = authorization.merge(extra)
        form = OpenidConnectAuthorizeForm.new(params)
        expect(form.submit.success?).to eq(true)
        expect(form.scope).to eq(%w[openid email])
        expect(form.requested_delegation_scopes).to be_empty
        expect(form.site_key_requested?).to eq(false)
        identity = form.link_identity_to_service_provider(
          current_user: create(:user), ial: 1, rails_session_id: SecureRandom.hex,
          email_address_id: nil
        )
        expect(identity.scope).to eq('openid email')
        expect(identity.dpop_jkt).to be_nil
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(300)
        token_params = {
          grant_type: 'authorization_code', code: identity.session_uuid, code_verifier: 'v' * 43
        }
        if pkce == false
          token_params[:client_assertion_type] = OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE
          token_params[:client_assertion] = build_client_assertion(
            client_id: sp.issuer, audience: api_openid_connect_token_url,
          )
        end
        post api_openid_connect_token_path, params: token_params,
                                            headers: { 'DPoP' => 'previously-ignored' }
        expect(response).to have_http_status(:ok)
        tokens = JSON.parse(response.body)
        expect(tokens.keys).to contain_exactly(
          'access_token', 'id_token', 'token_type',
          'expires_in'
        )
        expect(tokens['token_type']).to eq('Bearer')
        get api_openid_connect_userinfo_path,
            headers: { 'Authorization' => "Bearer #{tokens['access_token']}",
                       'DPoP' => 'previously-ignored' }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  it 'does not require DPoP for an unbound code issued before the client flag was enabled' do
    sp = create(:service_provider, pkce: true, dpop_required: false)
    user = create(:user)
    verifier = 'v' * 43
    identity = IdentityLinker.new(user, sp).link_identity(
      ial: 1, rails_session_id: SecureRandom.hex,
      acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      code_challenge: Digest::SHA256.urlsafe_base64digest(verifier)
    )
    sp.update!(dpop_required: true)
    form = OpenidConnectTokenForm.new(
      grant_type: 'authorization_code', code: identity.session_uuid, code_verifier: verifier,
    )
    expect(form.submit.success?).to eq(true)
  end

  it 'requires the original DPoP key after the per-client flag is disabled' do
    sp = create(:service_provider, pkce: true, dpop_required: true)
    user = create(:user)
    verifier = 'v' * 43
    identity = IdentityLinker.new(user, sp).link_identity(
      ial: 1, rails_session_id: SecureRandom.hex,
      acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      code_challenge: Digest::SHA256.urlsafe_base64digest(verifier),
      dpop_jkt: dpop_thumbprint
    )
    code = identity.session_uuid
    sp.update!(dpop_required: false)
    form = OpenidConnectTokenForm.new(
      grant_type: 'authorization_code', code:, code_verifier: verifier,
    )
    expect(form.submit.success?).to eq(false)
    expect(form.response[:error]).to eq('invalid_dpop_proof')
    expect(identity.reload.session_uuid).to eq(code)
  end

  it 'redeems a bound code with its key after rollback and keeps userinfo bound' do
    sp = create(:service_provider, pkce: true, dpop_required: true)
    identity = IdentityLinker.new(create(:user), sp).link_identity(
      ial: 1, rails_session_id: SecureRandom.hex,
      acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      code_challenge: Digest::SHA256.urlsafe_base64digest('v' * 43), dpop_jkt: dpop_thumbprint
    )
    OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(300)
    sp.update!(dpop_required: false)
    post api_openid_connect_token_path,
         params: { grant_type: 'authorization_code',
                   code: identity.session_uuid,
                   code_verifier: 'v' * 43 },
         headers: { 'DPoP' => build_dpop_proof(url: api_openid_connect_token_url) }
    expect(response).to have_http_status(:ok)
    token = JSON.parse(response.body)
    expect(token['token_type']).to eq('DPoP')
    get api_openid_connect_userinfo_path,
        headers: { 'Authorization' => "Bearer #{token['access_token']}" }
    expect(response).to have_http_status(:unauthorized)
    get api_openid_connect_userinfo_path,
        headers: { 'Authorization' => "DPoP #{token['access_token']}",
                   'DPoP' => build_dpop_proof(
                     url: api_openid_connect_userinfo_url, method: 'GET',
                     access_token: token['access_token']
                   ) }
    expect(response).to have_http_status(:ok)
  end

  context 'delegated families' do
    let(:user) { create(:user, :proofed) }
    let(:sp) do
      create(:service_provider, :delegation_service_provider, pkce: true, dpop_required: false)
    end
    let(:application) { create(:service_provider, :delegation_application) }
    let(:resource) { create(:token_exchange_resource_server, service_provider: application) }
    let!(:identity) do
      IdentityLinker.new(user, sp).link_identity(
        ial: 2, rails_session_id: 'original-session',
        acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR
      )
    end
    let!(:grant) do
      TokenExchangeGrant.approve!(
        user:, service_provider: sp, application:,
        source: 'consent_screen', remember: true
      )
    end
    let!(:issued) do
      create(
        :token_exchange_token, user:, service_provider: sp, resource_server: resource,
                               grant:, sp_rails_session_id: 'original-session'
      )
    end
    let(:refresh_token) { TokenExchangeRefreshToken.generate_token }
    let!(:refresh_row) do
      create(:token_exchange_refresh_token, token_exchange_token: issued, plaintext: refresh_token)
    end

    def renew
      form = OpenidConnectRefreshTokenForm.new(client_id: sp.issuer, refresh_token:)
      expect(form.submit.success?).to eq(true)
      form.response
    end

    def introspect(access_token)
      form = OpenidConnectIntrospectForm.new(client_id: sp.issuer, token: access_token)
      expect(form.submit.success?).to eq(true)
      form.response
    end

    it 'keeps an unbound family usable when DPoP is enabled for new authorizations' do
      sp.update!(dpop_required: true)
      result = renew
      expect(result[:token_type]).to eq('Bearer')
      expect(introspect(result[:access_token])[:active]).to eq(true)
      revoke = OpenidConnectRevokeForm.new(client_id: sp.issuer, token: result[:refresh_token])
      expect(revoke.submit.success?).to eq(true)
      expect(refresh_row.reload.revoked?).to eq(true)
    end

    it 'does not resurrect an access token when family revocation wins before Redis publication' do
      allow(DelegatedTokenStore).to receive(:write).and_wrap_original do |original, *args, **kwargs|
        TokenExchangeRefreshToken.revoke_family!(
          refresh_row.family_id, grant:,
                                 reason: 'client_revoked'
        )
        original.call(*args, **kwargs)
      end
      result = renew
      expect(refresh_row.reload.revoked?).to eq(true)
      expect(introspect(result[:access_token])[:active]).to eq(false)
    end

    it 'stops accepting existing tokens when the application removes the service provider' do
      access_token = renew[:access_token]
      expect(introspect(access_token)[:active]).to eq(true)
      application.update!(allowed_delegation_service_providers: ['another-provider'])
      expect(introspect(access_token)[:active]).to eq(false)
    end

    it 'issues usable refreshed tokens after a new sign-in for a single-authorization family' do
      grant.update!(remember_until: nil, rails_session_id: 'original-session')
      identity.update!(rails_session_id: 'new-session')
      access_token = renew[:access_token]
      expect(introspect(access_token)[:active]).to eq(true)
    end

    it 'keeps the original authentication time on an existing delegation after another sign-in' do
      original_auth_time = 1.hour.ago.change(usec: 0)
      identity.update!(last_authenticated_at: original_auth_time)
      issued.update!(authenticated_at: original_auth_time)
      access_token = renew[:access_token]
      identity.update!(last_authenticated_at: Time.zone.now)
      form = OpenidConnectIntrospectForm.new(
        token: access_token,
        client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
        client_assertion: build_client_assertion(
          client_id: resource.identifier, audience: api_openid_connect_introspect_url,
        ),
      )
      expect(form.submit.success?).to eq(true)
      expect(form.response[:active]).to eq(true)
      expect(form.response[:auth_time]).to eq(original_auth_time.to_i)
    end
  end
end
