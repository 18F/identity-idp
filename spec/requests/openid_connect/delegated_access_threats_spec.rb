require 'rails_helper'

# The cross-cutting refusals of delegated access, pinned end to end at the HTTP endpoints on the
# integrated code rather than one form at a time. Each example is one line of the threat table:
# a token or proof in the wrong hands, at the wrong place, or after the approval, the service
# provider or the API stopped being good for it. MyBenefits Assistant (Office of Benefits
# Coordination) is a browser public client acting for the person at Housing Assistance Records
# (Department of Housing Support); Retirement Benefits Portal (National Retirement
# Administration) is the API a token was not issued for.
RSpec.describe 'Delegated access threat sweep' do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user, :proofed) }
  let(:housing_agency) { create(:agency, name: 'Department of Housing Support') }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      agency: housing_agency,
      issuer: 'urn:gov:gsa:openidconnect:sp:records_agency',
      friendly_name: 'Housing Assistance Records',
      delegation_scope_value: 'housing_records',
      attribute_bundle: %w[email]
    )
  end
  let(:resource_server) do
    create(
      :token_exchange_resource_server,
      service_provider: application,
      identifier: 'https://records-api.housing.example.gov',
      certs: ['saml_test_sp'],
    )
  end
  let(:service_provider) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
      friendly_name: 'MyBenefits Assistant',
      pkce: true, certs: [],
      redirect_uris: ['https://mybenefits.example.gov/auth/result']
    )
  end
  let(:rails_session_id) { SecureRandom.hex }
  let!(:identity) { link_identity(service_provider, dpop_jkt: dpop_thumbprint) }
  let!(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  let(:subject_token) { identity.access_token }
  let(:token_url) { api_openid_connect_token_url }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    OutOfBandSessionAccessor.new(rails_session_id).put_pii(
      profile_id: user.active_profile.id,
      pii: { first_name: 'Ada', last_name: 'Lovelace' },
      expiration: 300,
    )
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  def link_identity(client, dpop_jkt:, session_id: rails_session_id)
    IdentityLinker.new(user, client).link_identity(
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      ial: 2,
      rails_session_id: session_id,
      scope: 'openid email token_exchange:housing_records',
      dpop_jkt:,
    )
  end

  # One RFC 8693 exchange as a public client: client_id plus a DPoP proof with ath over the
  # subject token. Every call signs a fresh proof unless one is given, since a jti is single-use.
  def exchange(token: subject_token, client: service_provider, key: dpop_key,
               resource: resource_server.identifier, proof: nil)
    proof ||= build_dpop_proof(url: token_url, access_token: token, key:)
    post api_openid_connect_token_path,
         params: {
           grant_type: OpenidConnectTokenExchangeForm::GRANT_TYPE,
           subject_token: token,
           subject_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
           requested_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
           resource:,
           client_id: client.issuer,
         },
         headers: { 'DPoP' => proof }
    json
  end

  def refresh(refresh_token, key: dpop_key)
    post api_openid_connect_token_path,
         params: { grant_type: 'refresh_token',
                   refresh_token:,
                   client_id: service_provider.issuer },
         headers: { 'DPoP' => build_dpop_proof(url: token_url, key:) }
    json
  end

  # RFC 7662 introspection as an agency API, with a private_key_jwt assertion naming the API.
  def introspect_as(identifier, token, key: saml_test_sp_private_key)
    post api_openid_connect_introspect_path, params: {
      token:,
      client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
      client_assertion: build_client_assertion(
        client_id: identifier, audience: api_openid_connect_introspect_url, key:,
      ),
    }
    json
  end

  def userinfo(authorization, proof: nil)
    get api_openid_connect_userinfo_path,
        headers: { 'HTTP_AUTHORIZATION' => authorization, 'DPoP' => proof }.compact
  end

  def dpop_error(key)
    { error: 'invalid_dpop_proof', error_description: t("openid_connect.token.errors.#{key}") }
  end

  describe 'a subject token that belongs to another client' do
    let(:other_service_provider) do
      create(
        :service_provider, :delegation_service_provider,
        issuer: 'urn:gov:gsa:openidconnect:sp:elsewhere',
        friendly_name: 'Elsewhere Assistant',
        pkce: true, certs: []
      )
    end
    let(:other_key) { OpenSSL::PKey::EC.generate('prime256v1') }
    let!(:other_identity) do
      link_identity(other_service_provider, dpop_jkt: dpop_thumbprint(other_key))
    end

    it 'is refused in both directions, each presenter proving possession of its own key' do
      stub_request_analytics

      expect(exchange(token: other_identity.access_token)).to eq(
        error: 'invalid_grant',
        error_description: t('openid_connect.token.errors.invalid_subject_token'),
      )
      expect(exchange(token: subject_token, client: other_service_provider, key: other_key)).to eq(
        error: 'invalid_grant',
        error_description: t('openid_connect.token.errors.invalid_subject_token'),
      )
      expect(TokenExchangeToken.count).to eq(0)
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        hash_including(
          success: false, service_provider_issuer: service_provider.issuer,
          client_type: 'public', error_code: 'invalid_grant'
        ),
      )
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        hash_including(
          success: false, service_provider_issuer: other_service_provider.issuer,
          error_code: 'invalid_grant'
        ),
      )
    end
  end

  describe 'a key-bound token presented as a bearer token' do
    it 'is refused at userinfo with the DPoP challenge, and accepted with the proof' do
      userinfo("Bearer #{subject_token}")
      expect(response).to have_http_status(:unauthorized)
      expect(response['WWW-Authenticate']).to eq('DPoP algs="ES256 RS256", error="invalid_token"')
      expect(json[:error]).to eq(t('openid_connect.user_info.errors.bound_token_requires_dpop'))

      userinfo(
        "DPoP #{subject_token}",
        proof: build_dpop_proof(
          url: api_openid_connect_userinfo_url, method: 'GET', access_token: subject_token,
        ),
      )
      expect(response).to have_http_status(:ok)
      expect(json[:sub]).to eq(identity.uuid)
    end

    it 'is refused at userinfo when it is a delegated token, with or without a proof' do
      delegated = exchange.fetch(:access_token)

      userinfo("Bearer #{delegated}")
      expect(response).to have_http_status(:unauthorized)

      userinfo(
        "DPoP #{delegated}",
        proof: build_dpop_proof(
          url: api_openid_connect_userinfo_url, method: 'GET', access_token: delegated,
        ),
      )
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'a replayed proof' do
    it 'is accepted once at the exchange and refused the second time with the same jti' do
      stub_request_analytics
      proof = build_dpop_proof(url: token_url, access_token: subject_token)

      expect(exchange(proof:)).to include(:access_token)
      expect(exchange(proof:)).to eq(dpop_error('dpop_proof_replayed'))
      expect(TokenExchangeToken.count).to eq(1)
      # The proof is checked before the resource is looked up, so a failed proof is logged
      # against the caller and the error code alone.
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        success: false,
        service_provider_issuer: service_provider.issuer,
        client_type: 'public',
        requested_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
        error_code: 'invalid_dpop_proof',
        error_details: { dpop_proof: { dpop_proof_replayed: true } },
      )
    end

    it 'is refused even when the first use was at another endpoint' do
      proof = build_dpop_proof(url: token_url, access_token: subject_token)
      expect(exchange(proof:)).to include(:access_token)

      # Same jti and key, now at introspection: the jti is spent for this key everywhere.
      post api_openid_connect_introspect_path,
           params: { token: subject_token, client_id: service_provider.issuer },
           headers: { 'DPoP' => proof }
      expect(response).to have_http_status(:unauthorized)
      expect(json[:error]).to eq('invalid_dpop_proof')
    end
  end

  describe 'a proof for another URL' do
    it 'is refused at the exchange' do
      stub_request_analytics
      elsewhere = [
        build_dpop_proof(url: api_openid_connect_introspect_url, access_token: subject_token),
        build_dpop_proof(url: api_openid_connect_userinfo_url, access_token: subject_token),
        build_dpop_proof(url: token_url, method: 'GET', access_token: subject_token),
      ]

      elsewhere.each do |proof|
        expect(exchange(proof:)).to eq(dpop_error('dpop_proof_invalid'))
      end
      expect(TokenExchangeToken.count).to eq(0)
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        hash_including(success: false, error_code: 'invalid_dpop_proof'),
      )
    end
  end

  describe 'an expired proof' do
    it 'is refused at the exchange and at userinfo' do
      stale = (IdentityConfig.store.dpop_proof_max_age_seconds + 60).seconds.ago.to_i

      expect(
        exchange(proof: build_dpop_proof(url: token_url, access_token: subject_token, iat: stale)),
      ).to eq(dpop_error('dpop_proof_invalid'))

      userinfo(
        "DPoP #{subject_token}",
        proof: build_dpop_proof(
          url: api_openid_connect_userinfo_url, method: 'GET', access_token: subject_token,
          iat: stale
        ),
      )
      expect(response).to have_http_status(:unauthorized)
      expect(response['WWW-Authenticate'])
        .to eq('DPoP algs="ES256 RS256", error="invalid_dpop_proof"')
      expect(TokenExchangeToken.count).to eq(0)
    end
  end

  describe 'a refresh with a different key' do
    it 'is refused, leaves the family intact, and the bound key still refreshes' do
      stub_request_analytics
      issued = exchange
      refresh_token = issued.fetch(:refresh_token)
      thief_key = OpenSSL::PKey::EC.generate('prime256v1')

      expect(refresh(refresh_token, key: thief_key)).to eq(dpop_error('dpop_key_mismatch'))
      presented = TokenExchangeRefreshToken.lookup(refresh_token)
      expect(presented.rotated_at).to be_nil
      expect(presented.revoked_at).to be_nil
      expect(TokenExchangeToken.count).to eq(1)
      expect(@analytics).to have_logged_event(
        :openid_connect_token_refresh,
        hash_including(
          success: false, service_provider_issuer: service_provider.issuer,
          resource_server_identifier: resource_server.identifier,
          client_type: 'public', error_code: 'invalid_dpop_proof'
        ),
      )

      renewed = refresh(refresh_token)
      expect(renewed).to include(:access_token, :refresh_token)
      expect(TokenExchangeToken.order(:id).last.dpop_jkt).to eq(dpop_thumbprint)
    end
  end

  describe 'introspection by the wrong audience' do
    let(:retirement_application) do
      create(
        :service_provider, :delegation_application,
        agency: create(:agency, name: 'National Retirement Administration'),
        issuer: 'urn:gov:gsa:SAML:2.0.profiles:sp:sso:benefits_agency',
        friendly_name: 'Retirement Benefits Portal',
        delegation_scope_value: 'retirement_benefits'
      )
    end
    let(:other_resource_server) do
      create(
        :token_exchange_resource_server,
        service_provider: retirement_application,
        identifier: 'https://benefits-api.retirement.example.gov',
        certs: ['saml_test_sp2'],
      )
    end

    it 'learns only that the token is not active, while the audience learns everything' do
      stub_request_analytics
      delegated = exchange.fetch(:access_token)

      expect(
        introspect_as(other_resource_server.identifier, delegated, key: saml_test_sp2_private_key),
      ).to eq(active: false)
      expect(response).to have_http_status(:ok)
      expect(@analytics).to have_logged_event(
        :openid_connect_introspect,
        success: true,
        caller_type: 'resource_server',
        resource_server_identifier: other_resource_server.identifier,
        active: false,
      )

      expect(introspect_as(resource_server.identifier, delegated)).to include(
        active: true,
        aud: resource_server.identifier,
        client_id: service_provider.issuer,
        token_type: 'DPoP',
        cnf: { jkt: dpop_thumbprint },
      )
    end
  end

  describe 'an exchange after the approval was revoked' do
    it 'asks for consent again and the earlier token is dead' do
      stub_request_analytics
      delegated = exchange.fetch(:access_token)
      grant.revoke!(reason: 'user_revoked')

      expect(introspect_as(resource_server.identifier, delegated)).to eq(active: false)
      expect(exchange).to eq(
        error: 'consent_required',
        error_description: t(
          'openid_connect.token.errors.consent_required',
          delegation_scope: 'token_exchange:housing_records',
        ),
      )
      expect(TokenExchangeToken.count).to eq(1)
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        hash_including(
          success: false, service_provider_issuer: service_provider.issuer,
          application_issuer: application.issuer, error_code: 'consent_required'
        ),
      )
    end
  end

  describe 'an exchange after Login.gov withdrew its approval of the service provider' do
    it 'is refused as an unapproved client and the earlier token is dead' do
      stub_request_analytics
      delegated = exchange.fetch(:access_token)
      service_provider.update!(token_exchange_enabled_sp: false)

      expect(exchange).to eq(
        error: 'invalid_client',
        error_description: t('openid_connect.token.errors.client_not_approved'),
      )
      expect(introspect_as(resource_server.identifier, delegated)).to eq(active: false)
      expect(TokenExchangeToken.count).to eq(1)
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        hash_including(
          success: false, service_provider_issuer: service_provider.issuer,
          error_code: 'invalid_client'
        ),
      )
    end
  end

  describe 'an exchange when the API or its application is switched off' do
    shared_examples 'an unavailable resource' do
      it 'is refused as an unknown resource and the earlier token is dead' do
        stub_request_analytics
        delegated = exchange.fetch(:access_token)
        switch_off

        expect(exchange).to eq(
          error: 'invalid_target',
          error_description: t('openid_connect.token.errors.unknown_resource'),
        )
        expect(introspect_as(resource_server.identifier, delegated)).to eq(active: false)
        expect(TokenExchangeToken.count).to eq(1)
        expect(@analytics).to have_logged_event(
          :openid_connect_token_exchange,
          hash_including(
            success: false, service_provider_issuer: service_provider.issuer,
            error_code: 'invalid_target'
          ),
        )
      end
    end

    context 'when the API URL is inactive' do
      def switch_off = resource_server.update!(active: false)

      include_examples 'an unavailable resource'
    end

    context 'when the agency switched its application off' do
      def switch_off = application.update!(active: false)

      include_examples 'an unavailable resource'
    end
  end
end
