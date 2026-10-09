require 'rails_helper'

# grant_type=refresh_token at POST /api/openid_connect/token for delegated-access families.
# MyBenefits Assistant (Office of Benefits Coordination) renews its access to Housing Assistance
# Records (Department of Housing Support), once as a confidential client and once as a
# browser-based public client.
RSpec.describe 'OpenID Connect delegated token refresh' do
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
  let(:family_expires_at) { 11.hours.from_now.change(usec: 0) }
  let(:previous_access_token) { TokenExchangeToken.generate_token }
  let!(:previous_issuance) do
    create(
      :token_exchange_token, grant:, resource_server:, service_provider:, user:,
                             token_type:, dpop_jkt: family_jkt, plaintext: previous_access_token,
                             sp_rails_session_id: 'sign-in-session', ial: 2, aal: 2,
                             issued_at: 10.minutes.ago, expires_at: 5.minutes.from_now
    )
  end
  let(:refresh_token) { TokenExchangeRefreshToken.generate_token }
  let!(:presented) do
    create(
      :token_exchange_refresh_token, token_exchange_token: previous_issuance,
                                     plaintext: refresh_token, expires_at: family_expires_at
    )
  end
  let(:extra_params) { {} }
  let(:headers) { {} }
  let(:params) do
    { grant_type: 'refresh_token', refresh_token: }.merge(credentials).merge(extra_params).compact
  end
  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled)
      .and_return(token_exchange_enabled)
  end

  def refresh
    post api_openid_connect_token_path, params:, headers:
  end

  # Everything that does not depend on how the client authenticates.
  shared_examples 'a token refresh' do |token_type:|
    describe 'a successful refresh' do
      it 'rotates the refresh token and mints the next access token of the family' do
        freeze_time do
          expect { refresh }.to change { TokenExchangeToken.count }.by(1)
            .and change { TokenExchangeRefreshToken.count }.by(1)

          expect(response).to have_http_status(:ok)
          expect(json.keys).to contain_exactly(
            :access_token, :issued_token_type, :token_type, :expires_in, :scope,
            :refresh_token, :refresh_token_expires_in
          )
          expect(json[:access_token]).to match(/\A[A-Za-z0-9_-]{43}\z/)
          expect(json[:access_token]).not_to eq(previous_access_token)
          expect(json[:issued_token_type])
            .to eq(OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE)
          expect(json[:token_type]).to eq(token_type)
          expect(json[:expires_in]).to eq(900)
          expect(json[:scope]).to eq('token_exchange:housing_records')
          expect(json[:refresh_token]).to match(/\A[A-Za-z0-9_-]{43}\z/)
          expect(json[:refresh_token]).not_to eq(refresh_token)
          expect(json[:refresh_token_expires_in]).to eq((family_expires_at - Time.zone.now).to_i)

          issued = TokenExchangeToken.order(:id).last
          expect(issued.grant).to eq(grant)
          expect(issued.resource_server).to eq(resource_server)
          expect(issued.service_provider).to eq(service_provider)
          expect(issued.user).to eq(user)
          expect(issued.delegation_id).to eq(grant.delegation_id)
          expect(issued.scope).to eq('token_exchange:housing_records')
          expect(issued.ial).to eq(2)
          expect(issued.aal).to eq(2)
          expect(issued.token_type).to eq(token_type)
          expect(issued.dpop_jkt).to eq(family_jkt)
          expect(issued.refresh_family_id).to eq(previous_issuance.refresh_family_id)
          expect(issued.sp_rails_session_id).to eq('sign-in-session')
          expect(issued.issued_at).to eq(Time.zone.now)
          expect(issued.expires_at).to eq(15.minutes.from_now)

          expect(DelegatedTokenStore.read(json[:access_token])).to include(
            aud: resource_server.identifier,
            scope: 'token_exchange:housing_records',
            grant_id: grant.id,
            delegation_id: grant.delegation_id,
            refresh_family_id: previous_issuance.refresh_family_id,
            dpop_jkt: family_jkt,
            token_type:,
            issuance_id: issued.id,
          )

          presented.reload
          expect(presented.rotated_at).to eq(Time.zone.now)
          expect(presented.used_at).to eq(Time.zone.now)
          expect(presented.revoked_at).to be_nil

          next_token = TokenExchangeRefreshToken.lookup(json[:refresh_token])
          expect(next_token.family_id).to eq(presented.family_id)
          expect(next_token.grant).to eq(grant)
          expect(next_token.token_exchange_token).to eq(issued)
          expect(next_token.scope).to eq(presented.scope)
          expect(next_token.dpop_jkt).to eq(family_jkt)
          expect(next_token.expires_at).to eq(family_expires_at)
          expect(next_token.rotated_at).to be_nil
          expect(next_token.attributes.values.map(&:to_s)).not_to include(json[:refresh_token])
        end
      end

      it 'leaves the earlier access token live for its own remaining lifetime' do
        refresh
        expect(DelegatedTokenStore.read(previous_access_token)).to be_present
        expect(previous_issuance.reload.revoked_at).to be_nil
      end

      it 'writes no new approval and no connection at the application' do
        expect { refresh }.not_to(change { ServiceProviderIdentity.count })
        expect(TokenExchangeGrant.where(user:).count).to eq(1)
      end

      it 'caps the access token at the API maximum when that is lower' do
        resource_server.update!(max_access_token_seconds: 300)
        refresh
        expect(json[:expires_in]).to eq(300)
      end

      it 'never lets an access token outlive the family' do
        freeze_time do
          presented.update!(expires_at: 2.minutes.from_now)
          refresh
          expect(json[:expires_in]).to eq(120)
          expect(json[:refresh_token_expires_in]).to eq(120)
        end
      end

      it 'can be repeated with the new refresh token' do
        refresh
        params[:refresh_token] = json[:refresh_token]
        renew_credentials
        refresh
        expect(response).to have_http_status(:ok)
        expect(TokenExchangeRefreshToken.where(family_id: presented.family_id).count).to eq(3)
      end

      it 'accepts a scope parameter equal to the family scope' do
        params[:scope] = 'token_exchange:housing_records'
        refresh
        expect(response).to have_http_status(:ok)
      end

      it 'rotates under a row lock on the presented token' do
        expect(TokenExchangeRefreshToken).to receive(:lock).and_call_original
        refresh
        expect(response).to have_http_status(:ok)
      end

      it 'logs the refresh' do
        stub_request_analytics
        refresh

        expect(@analytics).to have_logged_event(
          :openid_connect_token_refresh,
          success: true,
          service_provider_issuer: service_provider.issuer,
          resource_server_identifier: resource_server.identifier,
          application_issuer: application.issuer,
          client_type:,
          token_type:,
          family_id: presented.family_id,
          reuse_detected: false,
          expires_in: 900,
        )
        expect(@analytics).not_to have_logged_event(:delegation_refresh_token_reuse)
        expect(@analytics).not_to have_logged_event(:sp_integration_errors_present)
      end

      it 'follows a re-approval of the same application' do
        replacement = TokenExchangeGrant.approve!(
          user:, service_provider:, application:, source: 'account_page', remember: true,
        )
        refresh
        expect(response).to have_http_status(:ok)
        expect(TokenExchangeToken.order(:id).last.grant).to eq(replacement)
        expect(TokenExchangeRefreshToken.lookup(json[:refresh_token]).grant).to eq(replacement)
      end
    end

    describe 'the request' do
      shared_examples 'invalid_request' do |key|
        it "fails with invalid_request (#{key}) and changes nothing" do
          expect { refresh }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_request')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
          expect(presented.reload.rotated_at).to be_nil
        end
      end

      context 'with a resource parameter' do
        let(:extra_params) { { resource: resource_server.identifier } }

        include_examples 'invalid_request', 'resource_not_allowed_on_refresh'
      end

      context 'with a code_verifier' do
        let(:extra_params) { { code_verifier: SecureRandom.hex } }

        include_examples 'invalid_request', 'code_verifier_not_allowed'
      end

      context 'without a refresh_token' do
        let(:refresh_token) { nil }

        include_examples 'invalid_request', 'refresh_token_missing'
      end

      context 'with a scope other than the family scope' do
        let(:extra_params) { { scope: 'token_exchange:housing_records openid' } }

        it 'fails with invalid_scope and changes nothing' do
          expect { refresh }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_scope')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.refresh_scope_mismatch'))
          expect(presented.reload.rotated_at).to be_nil
        end
      end
    end

    describe 'the refresh token' do
      shared_examples 'invalid_grant' do |key|
        it "fails with invalid_grant (#{key}) and mints nothing" do
          expect { refresh }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_grant')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
        end
      end

      context 'unknown' do
        let(:extra_params) { { refresh_token: TokenExchangeRefreshToken.generate_token } }

        include_examples 'invalid_grant', 'invalid_refresh_token'
      end

      context 'issued to another service provider' do
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
        let(:other_refresh_token) { TokenExchangeRefreshToken.generate_token }
        let(:extra_params) { { refresh_token: other_refresh_token } }

        before do
          create(
            :token_exchange_refresh_token, token_exchange_token: other_issuance,
                                           plaintext: other_refresh_token
          )
        end

        include_examples 'invalid_grant', 'invalid_refresh_token'

        it 'leaves the other service provider\'s family untouched' do
          refresh
          other = TokenExchangeRefreshToken.lookup(other_refresh_token)
          expect(other.rotated_at).to be_nil
          expect(other.revoked_at).to be_nil
        end
      end

      context 'revoked' do
        before { presented.update!(revoked_at: 1.minute.ago, revocation_reason: 'user_revoked') }

        include_examples 'invalid_grant', 'invalid_refresh_token'
      end

      context 'when the family has ended' do
        let(:family_expires_at) { 1.second.ago }

        include_examples 'invalid_grant', 'invalid_refresh_token'
      end

      context 'when the approval was revoked' do
        before { grant.revoke!(reason: 'user_revoked') }

        include_examples 'invalid_grant', 'invalid_refresh_token'

        it 'had already ended the family' do
          refresh
          expect(presented.reload.revocation_reason).to eq('user_revoked')
        end
      end

      context 'when the agency materially changed its content since the approval' do
        before do
          application.update!(
            consent_content_version: application.consent_content_version + 1,
            consent_material_version: application.consent_material_version + 1,
          )
        end

        include_examples 'invalid_grant', 'invalid_refresh_token'

        it 'ends the family, since no refresh could succeed under the approval again' do
          refresh
          expect(presented.reload.revocation_reason).to eq('approval_lapsed')
          expect(previous_issuance.reload.revocation_reason).to eq('approval_lapsed')
          expect(DelegatedTokenStore.read(previous_access_token)).to be_nil
        end
      end

      context 'when the approval was a single authorization whose sign-in has ended' do
        before do
          grant.update!(remember_until: nil, rails_session_id: 'an-earlier-session')
        end

        it 'still refreshes: continued access does not depend on the sign-in' do
          refresh
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when the API URL is switched off' do
        before { resource_server.update!(active: false) }

        include_examples 'invalid_grant', 'invalid_refresh_token'

        it 'keeps the family, so switching the API back on restores it' do
          refresh
          expect(presented.reload.revoked_at).to be_nil
          expect(presented.rotated_at).to be_nil

          resource_server.update!(active: true)
          renew_credentials
          refresh
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when the application no longer lists this service provider' do
        before { application.update!(allowed_delegation_service_providers: ['urn:someone-else']) }

        include_examples 'invalid_grant', 'invalid_refresh_token'
      end

      context 'already rotated' do
        before do
          refresh
          expect(response).to have_http_status(:ok)
          @next_refresh_token = json[:refresh_token]
          @next_access_token = json[:access_token]
          renew_credentials
        end

        it 'ends the whole family and answers invalid_grant' do
          stub_request_analytics

          freeze_time do
            expect { refresh }.not_to(change { TokenExchangeToken.count })

            expect(response).to have_http_status(:bad_request)
            expect(json[:error]).to eq('invalid_grant')
            expect(json[:error_description])
              .to eq(t('openid_connect.token.errors.refresh_token_reused'))

            family = TokenExchangeRefreshToken.where(family_id: presented.family_id)
            expect(family.count).to eq(2)
            expect(family.map(&:revocation_reason).uniq).to eq(['refresh_token_reuse'])
            expect(family.map(&:revoked_at).uniq).to eq([Time.zone.now])
            expect(presented.reload.used_at).to eq(Time.zone.now)
            expect(TokenExchangeRefreshToken.lookup(@next_refresh_token).rotated_at).to be_nil

            issuances = TokenExchangeToken.where(refresh_family_id: presented.family_id)
            expect(issuances.count).to eq(2)
            expect(issuances.map(&:revocation_reason).uniq).to eq(['refresh_token_reuse'])
            expect(DelegatedTokenStore.read(previous_access_token)).to be_nil
            expect(DelegatedTokenStore.read(@next_access_token)).to be_nil

            expect(grant.reload.revoked_at).to be_nil
          end

          expect(@analytics).to have_logged_event(
            :openid_connect_token_refresh,
            hash_including(
              success: false, error_code: 'invalid_grant', reuse_detected: true,
              family_id: presented.family_id
            ),
          )
          expect(@analytics).to have_logged_event(
            :delegation_refresh_token_reuse,
            service_provider_issuer: service_provider.issuer,
            resource_server_identifier: resource_server.identifier,
            family_id: presented.family_id,
          )
        end

        it 'refuses the rotated-to token as well, and reports the theft only once' do
          refresh
          expect(json[:error]).to eq('invalid_grant')

          stub_request_analytics
          params[:refresh_token] = @next_refresh_token
          renew_credentials
          refresh
          expect(json[:error]).to eq('invalid_grant')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.invalid_refresh_token'))
          expect(@analytics).not_to have_logged_event(:delegation_refresh_token_reuse)

          params[:refresh_token] = refresh_token
          renew_credentials
          refresh
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.refresh_token_reused'))
          expect(@analytics).not_to have_logged_event(:delegation_refresh_token_reuse)
        end
      end
    end

    context 'when delegated access is switched off' do
      let(:token_exchange_enabled) { false }

      it 'answers unsupported_grant_type' do
        refresh
        expect(response).to have_http_status(:bad_request)
        expect(json).to eq(
          error: 'unsupported_grant_type',
          error_description: t('openid_connect.token.errors.unsupported_grant_type'),
        )
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
        client_id: service_provider.issuer, audience: api_openid_connect_token_url,
      )
    end
    let(:credentials) do
      { client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE, client_assertion: }
    end

    # A second request needs a fresh assertion: the jti of the first has been used.
    def renew_credentials
      params[:client_assertion] = build_client_assertion(
        client_id: service_provider.issuer, audience: api_openid_connect_token_url,
      )
    end

    include_examples 'a token refresh', token_type: 'Bearer'

    describe 'client authentication' do
      shared_examples 'invalid_client' do
        it 'fails with invalid_client and touches nothing' do
          stub_request_analytics
          expect { refresh }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description]).to be_present
          expect(presented.reload.rotated_at).to be_nil
          expect(@analytics).to have_logged_event(
            :openid_connect_token_refresh,
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
            client_id: service_provider.issuer, audience: api_openid_connect_token_url,
            key: OpenSSL::PKey::RSA.new(2048)
          )
        end

        include_examples 'invalid_client'

        it 'logs the integration error for the claimed issuer' do
          stub_request_analytics
          refresh
          expect(@analytics).to have_logged_event(
            :sp_integration_errors_present,
            hash_including(
              event: :oidc_token_refresh_request,
              integration_exists: true,
              request_issuer: service_provider.issuer,
            ),
          )
        end
      end

      context 'when the assertion was minted for a different endpoint' do
        let(:client_assertion) do
          build_client_assertion(
            client_id: service_provider.issuer, audience: api_openid_connect_revoke_url,
          )
        end

        include_examples 'invalid_client'
      end

      context 'when the client only names itself' do
        let(:credentials) { { client_id: service_provider.issuer } }

        include_examples 'invalid_client'
      end

      context 'when the client is no longer approved for delegation' do
        before { service_provider.update!(token_exchange_enabled_sp: false) }

        include_examples 'invalid_client'
      end

      it 'withholds everything about the token from an unauthenticated caller' do
        params.delete(:client_assertion)
        params[:refresh_token] = 'not-a-token'
        refresh
        expect(json[:error]).to eq('invalid_client')
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
    let(:proof) { build_dpop_proof(url: api_openid_connect_token_url) }

    # A second request needs a fresh proof: the jti of the first has been used.
    def renew_credentials
      headers['DPoP'] = build_dpop_proof(url: api_openid_connect_token_url)
    end

    include_examples 'a token refresh', token_type: 'DPoP'

    describe 'the proof' do
      shared_examples 'invalid_dpop_proof' do |key|
        it "fails with invalid_dpop_proof (#{key}) and does not rotate the family" do
          stub_request_analytics
          expect { refresh }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
          expect(presented.reload.rotated_at).to be_nil
          expect(presented.revoked_at).to be_nil
          expect(@analytics).to have_logged_event(
            :openid_connect_token_refresh,
            hash_including(success: false, client_type: 'public', error_code: 'invalid_dpop_proof'),
          )
        end
      end

      context 'missing' do
        let(:headers) { {} }

        include_examples 'invalid_dpop_proof', 'dpop_proof_required'
      end

      context 'signed by a key other than the one the family is bound to' do
        let(:proof) do
          build_dpop_proof(
            url: api_openid_connect_token_url, key: OpenSSL::PKey::EC.generate('prime256v1'),
          )
        end

        include_examples 'invalid_dpop_proof', 'dpop_key_mismatch'
      end

      context 'carrying ath although no access token is presented' do
        let(:proof) do
          build_dpop_proof(url: api_openid_connect_token_url, access_token: refresh_token)
        end

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'for another endpoint' do
        let(:proof) { build_dpop_proof(url: api_openid_connect_revoke_url) }

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'replayed' do
        it 'accepts the first use and refuses the second' do
          refresh
          expect(response).to have_http_status(:ok)
          params[:refresh_token] = json[:refresh_token]
          refresh
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.dpop_proof_replayed'))
        end
      end
    end

    describe 'client identification' do
      context 'with an unknown client_id' do
        let(:credentials) { { client_id: 'urn:gov:gsa:openidconnect:sp:nobody' } }

        it 'fails with invalid_client' do
          refresh
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description]).to eq(t('openid_connect.token.errors.unknown_client'))
        end
      end

      context 'with a client assertion from a public client' do
        let(:credentials) do
          {
            client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
            client_assertion: build_client_assertion(
              client_id: service_provider.issuer, audience: api_openid_connect_token_url,
            ),
          }
        end

        before { service_provider.update!(certs: ['saml_test_sp']) }

        it 'fails with invalid_client' do
          refresh
          expect(json[:error]).to eq('invalid_client')
        end
      end

      it 'withholds everything about the token from a caller without a proof' do
        headers.delete('DPoP')
        params[:refresh_token] = 'not-a-token'
        refresh
        expect(json[:error]).to eq('invalid_dpop_proof')
      end
    end
  end
end
