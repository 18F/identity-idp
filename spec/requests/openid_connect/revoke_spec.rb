require 'rails_helper'

# RFC 7009 revocation at POST /api/openid_connect/revoke. MyBenefits Assistant (Office of Benefits
# Coordination) ends its delegated access to Housing Assistance Records (Department of Housing
# Support) early, once as a confidential client and once as a browser-based public client.
RSpec.describe 'OpenID Connect delegated token revocation' do
  include Rails.application.routes.url_helpers

  let(:token_exchange_enabled) { true }
  let(:user) { create(:user, :proofed) }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      issuer: 'urn:gov:gsa:openidconnect:sp:records_agency',
      friendly_name: 'Housing Assistance Records',
      delegation_scope_value: 'housing_records'
    )
  end
  let(:resource_server) do
    create(
      :token_exchange_resource_server,
      service_provider: application,
      identifier: 'https://records-api.housing.example.gov',
    )
  end
  let!(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  let(:access_token) { TokenExchangeToken.generate_token }
  let!(:issuance) do
    create(
      :token_exchange_token, grant:, resource_server:, service_provider:, user:,
                             token_type:, dpop_jkt: family_jkt, plaintext: access_token
    )
  end
  let(:refresh_token) { TokenExchangeRefreshToken.generate_token }
  let!(:refresh_row) do
    create(:token_exchange_refresh_token, token_exchange_token: issuance, plaintext: refresh_token)
  end
  # A second access token of the same family, as a refresh leaves behind.
  let(:sibling_access_token) { TokenExchangeToken.generate_token }
  let!(:sibling_issuance) do
    create(
      :token_exchange_token, grant:, resource_server:, service_provider:, user:,
                             token_type:, dpop_jkt: family_jkt,
                             refresh_family_id: issuance.refresh_family_id,
                             plaintext: sibling_access_token
    )
  end
  let(:token) { refresh_token }
  let(:extra_params) { {} }
  let(:headers) { {} }
  let(:params) { { token: }.merge(credentials).merge(extra_params).compact }
  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled)
      .and_return(token_exchange_enabled)
  end

  def revoke
    post api_openid_connect_revoke_path, params:, headers:
  end

  def family_rows
    TokenExchangeRefreshToken.where(family_id: issuance.refresh_family_id)
  end

  def family_issuances
    TokenExchangeToken.where(refresh_family_id: issuance.refresh_family_id)
  end

  shared_examples 'a revocation endpoint' do
    shared_examples 'answers 200 with an empty object' do
      it 'answers 200 with an empty object' do
        revoke
        expect(response).to have_http_status(:ok)
        expect(json).to eq({})
      end
    end

    describe 'presenting a refresh token' do
      include_examples 'answers 200 with an empty object'

      it 'ends the whole family and nothing else' do
        freeze_time do
          revoke

          expect(DelegatedTokenStore.read(access_token)).to be_nil
          expect(DelegatedTokenStore.read(sibling_access_token)).to be_nil
          expect(family_rows.map(&:revoked_at).uniq).to eq([Time.zone.now])
          expect(family_rows.map(&:revocation_reason).uniq).to eq(['client_revoked'])
          expect(family_issuances.map(&:revoked_at).uniq).to eq([Time.zone.now])
          expect(family_issuances.map(&:revocation_reason).uniq).to eq(['client_revoked'])
          expect(grant.reload.revoked_at).to be_nil
        end
      end

      it 'logs the revocation' do
        stub_request_analytics
        revoke
        expect(@analytics).to have_logged_event(
          :openid_connect_revoke,
          success: true, service_provider_issuer: service_provider.issuer, client_type:,
          revoked: 'refresh_token'
        )
      end

      it 'finds it with a wrong hint' do
        params[:token_type_hint] = 'access_token'
        revoke
        expect(response).to have_http_status(:ok)
        expect(refresh_row.reload.revocation_reason).to eq('client_revoked')
      end

      it 'is unaffected by a hint it does not know' do
        params[:token_type_hint] = 'saml_assertion'
        revoke
        expect(response).to have_http_status(:ok)
        expect(refresh_row.reload.revocation_reason).to eq('client_revoked')
      end

      it 'leaves a family that already ended as it was' do
        stub_request_analytics
        TokenExchangeRefreshToken.revoke_family!(
          issuance.refresh_family_id, grant: issuance.grant, reason: 'user_revoked'
        )
        revoke
        expect(response).to have_http_status(:ok)
        expect(refresh_row.reload.revocation_reason).to eq('user_revoked')
        expect(@analytics).to have_logged_event(
          :openid_connect_revoke, hash_including(success: true, revoked: 'refresh_token')
        )
      end

      it 'refuses a refresh at the token endpoint afterwards' do
        revoke
        expect(TokenExchangeRefreshToken.lookup(refresh_token).revoked_at).to be_present
      end
    end

    describe 'presenting a delegated access token' do
      let(:token) { access_token }
      let(:extra_params) { { token_type_hint: 'access_token' } }

      include_examples 'answers 200 with an empty object'

      it 'ends that token alone and leaves the rest of the family working' do
        stub_request_analytics
        freeze_time do
          revoke

          expect(DelegatedTokenStore.read(access_token)).to be_nil
          expect(issuance.reload.revoked_at).to eq(Time.zone.now)
          expect(issuance.revocation_reason).to eq('client_revoked')
          expect(DelegatedTokenStore.read(sibling_access_token)).to be_present
          expect(sibling_issuance.reload.revoked_at).to be_nil
          expect(refresh_row.reload.revoked_at).to be_nil
        end
        expect(@analytics).to have_logged_event(
          :openid_connect_revoke,
          hash_including(success: true, token_type_hint: 'access_token', revoked: 'access_token'),
        )
      end

      it 'finds it without a hint' do
        params.delete(:token_type_hint)
        revoke
        expect(DelegatedTokenStore.read(access_token)).to be_nil
      end
    end

    describe 'tokens that are not acted on' do
      shared_examples 'acts on nothing' do
        it 'answers 200 with an empty object and changes nothing' do
          stub_request_analytics
          revoke

          expect(response).to have_http_status(:ok)
          expect(json).to eq({})
          expect(DelegatedTokenStore.read(access_token)).to be_present
          expect(DelegatedTokenStore.read(sibling_access_token)).to be_present
          expect(family_rows.map(&:revoked_at).compact).to be_empty
          expect(family_issuances.map(&:revoked_at).compact).to be_empty
          expect(@analytics).to have_logged_event(
            :openid_connect_revoke, hash_including(success: true, revoked: 'none')
          )
        end
      end

      context 'an unknown token' do
        let(:token) { SecureRandom.urlsafe_base64(32) }

        include_examples 'acts on nothing'
      end

      context 'another service provider\'s refresh token' do
        let(:other_client) do
          create(:service_provider, :delegation_service_provider, pkce: service_provider.pkce)
        end
        let(:other_grant) do
          TokenExchangeGrant.approve!(
            user:, service_provider: other_client, application:, source: 'consent_screen',
            remember: true
          )
        end
        let(:other_issuance) do
          create(
            :token_exchange_token, grant: other_grant, resource_server:,
                                   service_provider: other_client, user:, dpop_jkt: family_jkt
          )
        end
        let(:token) { TokenExchangeRefreshToken.generate_token }

        before do
          create(
            :token_exchange_refresh_token, token_exchange_token: other_issuance, plaintext: token
          )
        end

        include_examples 'acts on nothing'

        it 'leaves the other service provider\'s family untouched' do
          revoke
          expect(TokenExchangeRefreshToken.lookup(token).revoked_at).to be_nil
        end
      end

      context 'another service provider\'s access token' do
        let(:other_client) do
          create(:service_provider, :delegation_service_provider, pkce: service_provider.pkce)
        end
        let(:other_grant) do
          TokenExchangeGrant.approve!(
            user:, service_provider: other_client, application:, source: 'consent_screen',
            remember: true
          )
        end
        let(:token) { TokenExchangeToken.generate_token }

        before do
          create(
            :token_exchange_token, grant: other_grant, resource_server:,
                                   service_provider: other_client, user:, dpop_jkt: family_jkt,
                                   plaintext: token
          )
        end

        include_examples 'acts on nothing'

        it 'leaves the other service provider\'s token live' do
          revoke
          expect(DelegatedTokenStore.read(token)).to be_present
        end
      end

      context 'the service provider\'s own sign-in access token' do
        let(:identity) do
          IdentityLinker.new(user, service_provider).link_identity(
            ial: 2, rails_session_id: SecureRandom.hex, dpop_jkt: family_jkt,
          )
        end
        let(:token) { identity.access_token }

        include_examples 'acts on nothing'

        it 'leaves the sign-in as it was' do
          revoke
          expect(identity.reload.access_token).to eq(token)
          expect(identity.deleted_at).to be_nil
        end
      end
    end

    describe 'the request' do
      context 'without a token' do
        let(:token) { nil }

        it 'fails with invalid_request' do
          revoke
          expect(response).to have_http_status(:bad_request)
          expect(json).to eq(
            error: 'invalid_request',
            error_description: t('openid_connect.revoke.errors.token_missing'),
          )
        end
      end
    end

    context 'when delegated access is switched off' do
      let(:token_exchange_enabled) { false }

      it 'is not found' do
        revoke
        expect(response).to have_http_status(:not_found)
        expect(refresh_row.reload.revoked_at).to be_nil
      end
    end
  end

  context 'as a confidential client' do
    let(:service_provider) do
      create(
        :service_provider, :delegation_service_provider,
        issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
        friendly_name: 'MyBenefits Assistant',
        pkce: false, certs: ['saml_test_sp']
      )
    end
    let(:client_type) { 'confidential' }
    let(:token_type) { 'Bearer' }
    let(:family_jkt) { nil }
    let(:client_assertion) do
      build_client_assertion(
        client_id: service_provider.issuer, audience: api_openid_connect_revoke_url,
      )
    end
    let(:credentials) do
      { client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE, client_assertion: }
    end

    include_examples 'a revocation endpoint'

    describe 'client authentication' do
      shared_examples 'invalid_client' do
        it 'fails with 401 invalid_client and revokes nothing' do
          stub_request_analytics
          revoke
          expect(response).to have_http_status(:unauthorized)
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description]).to be_present
          expect(refresh_row.reload.revoked_at).to be_nil
          expect(DelegatedTokenStore.read(access_token)).to be_present
          expect(@analytics).to have_logged_event(
            :openid_connect_revoke,
            hash_including(success: false, error_code: 'invalid_client'),
          )
        end
      end

      context 'without any credential' do
        let(:credentials) { {} }

        include_examples 'invalid_client'
      end

      context 'when the signature does not match the registered certificates' do
        let(:client_assertion) do
          build_client_assertion(
            client_id: service_provider.issuer, audience: api_openid_connect_revoke_url,
            key: OpenSSL::PKey::RSA.new(2048)
          )
        end

        include_examples 'invalid_client'

        it 'logs the integration error for the claimed issuer' do
          stub_request_analytics
          revoke
          expect(@analytics).to have_logged_event(
            :sp_integration_errors_present,
            hash_including(
              event: :oidc_revoke_request,
              integration_exists: true,
              request_issuer: service_provider.issuer,
            ),
          )
        end
      end

      context 'when the assertion was minted for the token endpoint' do
        let(:client_assertion) do
          build_client_assertion(
            client_id: service_provider.issuer, audience: api_openid_connect_token_url,
          )
        end

        include_examples 'invalid_client'
      end

      context 'when the client only names itself' do
        let(:credentials) { { client_id: service_provider.issuer } }

        include_examples 'invalid_client'
      end

      context 'when the client is not approved for delegation' do
        before { service_provider.update!(token_exchange_enabled_sp: false) }

        include_examples 'invalid_client'
      end

      context 'when the same assertion is replayed' do
        it 'accepts the first and rejects the second' do
          revoke
          expect(response).to have_http_status(:ok)
          revoke
          expect(response).to have_http_status(:unauthorized)
          expect(json[:error]).to eq('invalid_client')
        end
      end
    end
  end

  context 'as a public client' do
    let(:service_provider) do
      create(
        :service_provider, :delegation_service_provider,
        issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
        friendly_name: 'MyBenefits Assistant',
        pkce: true, certs: []
      )
    end
    let(:client_type) { 'public' }
    let(:token_type) { 'DPoP' }
    let(:family_jkt) { dpop_thumbprint }
    let(:credentials) { { client_id: service_provider.issuer } }
    let(:headers) { { 'DPoP' => proof } }
    let(:proof) { build_dpop_proof(url: api_openid_connect_revoke_url, access_token: token) }

    include_examples 'a revocation endpoint'

    describe 'the proof' do
      shared_examples 'invalid_dpop_proof' do |key|
        it "fails with 400 invalid_dpop_proof (#{key}) and revokes nothing" do
          stub_request_analytics
          revoke
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
          expect(refresh_row.reload.revoked_at).to be_nil
          expect(DelegatedTokenStore.read(access_token)).to be_present
          expect(@analytics).to have_logged_event(
            :openid_connect_revoke,
            hash_including(success: false, client_type: 'public', error_code: 'invalid_dpop_proof'),
          )
        end
      end

      context 'missing' do
        let(:headers) { {} }

        include_examples 'invalid_dpop_proof', 'dpop_proof_required'
      end

      context 'without ath over the presented token' do
        let(:proof) { build_dpop_proof(url: api_openid_connect_revoke_url) }

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'with ath over a different token' do
        let(:proof) do
          build_dpop_proof(url: api_openid_connect_revoke_url, access_token: access_token)
        end

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'for the token endpoint' do
        let(:proof) { build_dpop_proof(url: api_openid_connect_token_url, access_token: token) }

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'replayed' do
        it 'accepts the first use and refuses the second' do
          revoke
          expect(response).to have_http_status(:ok)
          revoke
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.dpop_proof_replayed'))
        end
      end

      context 'signed by a key other than the one the family is bound to' do
        let(:proof) do
          build_dpop_proof(
            url: api_openid_connect_revoke_url, access_token: token,
            key: OpenSSL::PKey::EC.generate('prime256v1')
          )
        end

        it 'answers 200 and acts on nothing: holding a token is not holding its key' do
          stub_request_analytics
          revoke
          expect(response).to have_http_status(:ok)
          expect(json).to eq({})
          expect(refresh_row.reload.revoked_at).to be_nil
          expect(@analytics).to have_logged_event(
            :openid_connect_revoke, hash_including(success: true, revoked: 'none')
          )
        end

        context 'presenting an access token' do
          let(:token) { access_token }

          it 'acts on nothing' do
            revoke
            expect(response).to have_http_status(:ok)
            expect(DelegatedTokenStore.read(access_token)).to be_present
          end
        end
      end
    end

    describe 'client identification' do
      context 'with an unknown client_id' do
        let(:credentials) { { client_id: 'urn:gov:gsa:openidconnect:sp:nobody' } }

        it 'fails with 401 invalid_client' do
          revoke
          expect(response).to have_http_status(:unauthorized)
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description]).to eq(t('openid_connect.token.errors.unknown_client'))
        end
      end

      context 'with a client assertion from a public client' do
        let(:credentials) do
          {
            client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
            client_assertion: build_client_assertion(
              client_id: service_provider.issuer, audience: api_openid_connect_revoke_url,
            ),
          }
        end

        before { service_provider.update!(certs: ['saml_test_sp']) }

        it 'fails with 401 invalid_client' do
          revoke
          expect(response).to have_http_status(:unauthorized)
          expect(json[:error]).to eq('invalid_client')
        end
      end
    end
  end
end
