require 'rails_helper'

# RFC 8693 token exchange at POST /api/openid_connect/token. MyBenefits Assistant (Office of
# Benefits Coordination) acts for the person at Housing Assistance Records (Department of Housing
# Support), once as a confidential client and once as a browser-based public client.
RSpec.describe 'OpenID Connect token exchange' do
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
  let(:identity_ial) { 2 }
  let(:rails_session_id) { SecureRandom.hex }
  let(:subject_token) { identity.access_token }
  let(:resource) { resource_server.identifier }
  let(:requested_token_type) { OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE }
  let(:extra_params) { {} }
  let(:headers) { {} }
  let(:params) do
    {
      grant_type: OpenidConnectTokenExchangeForm::GRANT_TYPE,
      subject_token:,
      subject_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
      requested_token_type:,
      resource:,
    }.merge(credentials).merge(extra_params).compact
  end
  let!(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled)
      .and_return(token_exchange_enabled)
    OutOfBandSessionAccessor.new(rails_session_id).put_empty_user_session(300)
  end

  def exchange
    post api_openid_connect_token_path, params:, headers:
  end

  def link_identity(service_provider, dpop_jkt: nil)
    IdentityLinker.new(user, service_provider).link_identity(
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      ial: identity_ial,
      rails_session_id:,
      scope: 'openid email token_exchange:housing_records',
      dpop_jkt:,
    )
  end

  # Everything that does not depend on how the client authenticates.
  shared_examples 'a token exchange' do |token_type:|
    describe 'issuing a token' do
      it 'issues an opaque token for the one API, with the RFC 8693 response and nothing else' do
        freeze_time do
          exchange

          expect(response).to have_http_status(:ok)
          expect(json.keys).to contain_exactly(
            :access_token, :issued_token_type, :token_type, :expires_in, :scope,
            :refresh_token, :refresh_token_expires_in
          )
          expect(json[:access_token]).to match(/\A[A-Za-z0-9_-]{43}\z/)
          expect(json[:issued_token_type])
            .to eq(OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE)
          expect(json[:token_type]).to eq(token_type)
          expect(json[:expires_in]).to eq(900)
          expect(json[:scope]).to eq('token_exchange:housing_records')

          issued = TokenExchangeToken.last
          expect(issued.grant).to eq(grant)
          expect(issued.resource_server).to eq(resource_server)
          expect(issued.service_provider).to eq(service_provider)
          expect(issued.user).to eq(user)
          expect(issued.delegation_id).to eq(grant.delegation_id)
          expect(issued.scope).to eq('token_exchange:housing_records')
          expect(issued.ial).to eq(2)
          expect(issued.aal).to eq(2)
          expect(issued.token_type).to eq(token_type)
          expect(issued.token_format).to eq('oauth')
          expect(issued.refresh_family_id).to be_present
          expect(issued.sp_rails_session_id).to eq(rails_session_id)
          expect(issued.issued_at).to eq(Time.zone.now)
          expect(issued.expires_at).to eq(15.minutes.from_now)
          expect(issued.attributes.values.map(&:to_s)).not_to include(json[:access_token])

          live = DelegatedTokenStore.read(json[:access_token])
          expect(live).to include(
            aud: resource_server.identifier,
            scope: 'token_exchange:housing_records',
            grant_id: grant.id,
            delegation_id: grant.delegation_id,
            user_id: user.id,
            service_provider_id: service_provider.id,
            resource_server_id: resource_server.id,
            ial: 2,
            aal: 2,
            refresh_family_id: issued.refresh_family_id,
            token_type:,
            expires_at: 15.minutes.from_now.to_i,
            issuance_id: issued.id,
          )
          expect(grant.reload.first_exchanged_at).to eq(Time.zone.now)
        end
      end

      it 'opens a refresh family ending twelve hours from now, storing only the digest' do
        freeze_time do
          exchange

          expect(json[:refresh_token]).to match(/\A[A-Za-z0-9_-]{43}\z/)
          expect(json[:refresh_token]).not_to eq(json[:access_token])
          expect(json[:refresh_token_expires_in]).to eq(12.hours.to_i)

          issued = TokenExchangeToken.last
          refresh = TokenExchangeRefreshToken.last
          expect(refresh.token_digest).to eq(TokenExchangeRefreshToken.digest(json[:refresh_token]))
          expect(refresh.attributes.values.map(&:to_s)).not_to include(json[:refresh_token])
          expect(refresh.family_id).to eq(issued.refresh_family_id)
          expect(refresh.token_exchange_token).to eq(issued)
          expect(refresh.grant).to eq(grant)
          expect(refresh.resource_server).to eq(resource_server)
          expect(refresh.service_provider).to eq(service_provider)
          expect(refresh.user).to eq(user)
          expect(refresh.scope).to eq('token_exchange:housing_records')
          expect(refresh.dpop_jkt).to eq(issued.dpop_jkt)
          expect(refresh.expires_at).to eq(12.hours.from_now)
          expect(refresh.rotated_at).to be_nil
          expect(refresh.used_at).to be_nil
          expect(TokenExchangeRefreshToken.lookup(json[:refresh_token])).to eq(refresh)
        end
      end

      it 'shortens the family to the API maximum when that is lower' do
        resource_server.update!(max_family_seconds: 4.hours.to_i)
        exchange
        expect(json[:refresh_token_expires_in]).to eq(4.hours.to_i)
      end

      it 'shortens the family to the service provider maximum when that is lower' do
        service_provider.update!(delegation_max_family_seconds: 2.hours.to_i)
        resource_server.update!(max_family_seconds: 4.hours.to_i)
        exchange
        expect(json[:refresh_token_expires_in]).to eq(2.hours.to_i)
      end

      it 'never lengthens the family past the default' do
        resource_server.update!(max_family_seconds: 2.days.to_i)
        exchange
        expect(json[:refresh_token_expires_in]).to eq(12.hours.to_i)
      end

      it 'ends the family no later than the remembered approval, and the token with it' do
        freeze_time do
          grant.update!(remember_until: 10.minutes.from_now)
          exchange
          expect(json[:refresh_token_expires_in]).to eq(10.minutes.to_i)
          expect(json[:expires_in]).to eq(10.minutes.to_i)
          expect(TokenExchangeRefreshToken.last.expires_at).to eq(grant.remember_until)
        end
      end

      it 'gives a single-authorization approval the full family lifetime' do
        grant.update!(remember_until: nil, rails_session_id:)
        exchange
        expect(json[:refresh_token_expires_in]).to eq(12.hours.to_i)
      end

      it 'creates nothing at the application and leaves the subject token untouched' do
        expect { exchange }.not_to(change { ServiceProviderIdentity.count })
        expect(ServiceProviderIdentity.where(service_provider: application.issuer)).to be_empty
        expect(identity.reload.access_token).to eq(subject_token)
        expect(TokenExchangeGrant.live.where(user:).count).to eq(1)
      end

      it 'keeps the first-exchange time of the approval' do
        first = 2.hours.ago.change(usec: 0)
        grant.update!(first_exchanged_at: first)
        exchange
        expect(grant.reload.first_exchanged_at).to eq(first)
      end

      it 'caps the lifetime at the API maximum when that is lower' do
        resource_server.update!(max_access_token_seconds: 300)
        exchange
        expect(json[:expires_in]).to eq(300)
        expect(TokenExchangeToken.last.lifetime_seconds).to eq(300)
      end

      it 'never lengthens the lifetime past the default' do
        resource_server.update!(max_access_token_seconds: 3600)
        exchange
        expect(json[:expires_in]).to eq(900)
      end

      it 'logs the exchange' do
        stub_request_analytics
        exchange

        expect(@analytics).to have_logged_event(
          :openid_connect_token_exchange,
          success: true,
          service_provider_issuer: service_provider.issuer,
          resource_server_identifier: resource_server.identifier,
          application_issuer: application.issuer,
          client_type:,
          token_type:,
          requested_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
          expires_in: 900,
        )
        expect(@analytics).not_to have_logged_event(:sp_integration_errors_present)
      end

      it 'forwards the authentication assurance recorded on the identity when there is one' do
        identity.update!(aal: 3)
        exchange
        expect(TokenExchangeToken.last.aal).to eq(3)
      end

      describe 'telling the agency' do
        let(:redis_client) { AttemptsApi::RedisClient.new }
        let(:delivery_enabled) { true }

        before do
          allow(IdentityConfig.store).to receive_messages(
            attempts_api_enabled: true,
            token_exchange_attempts_delivery_enabled: delivery_enabled,
            allowed_attempts_providers: [{ 'issuer' => application.issuer, 'keys' => [] }],
          )
        end

        def agency_events
          redis_client.read_events(issuer: application.issuer).values.map do |jwe|
            AttemptsApi::AttemptEvent.from_jwe(jwe, saml_test_sp_private_key)
          end
        end

        it 'delivers a token-issued event to the application agency' do
          exchange

          expect(response).to have_http_status(:ok)
          events = agency_events
          expect(events.map(&:event_type)).to eq(['delegated-access-token-issued'])
          expect(events.first.event_metadata).to include(
            delegation_id: grant.delegation_id,
            actor_issuer: service_provider.issuer,
            application: application.issuer,
            resource: resource_server.identifier,
            scope: 'token_exchange:housing_records',
            token_type:,
            user_uuid: AgencyIdentity.find_by(user:, agency: application.agency).uuid,
          )
          expect(events.first.event_metadata).not_to have_key(:user_ip_address)
          expect(ServiceProviderIdentity.where(service_provider: application.issuer)).to be_empty
        end

        it 'issues the token even when delivery fails' do
          allow(AttemptsApi::RedisClient).to receive(:new).and_raise(Redis::CannotConnectError)

          exchange

          expect(response).to have_http_status(:ok)
          expect(DelegatedTokenStore.read(json[:access_token])).to be_present
        end

        context 'when delivery to agencies is switched off' do
          let(:delivery_enabled) { false }

          it 'issues the token and tells the agency nothing' do
            exchange

            expect(response).to have_http_status(:ok)
            expect(redis_client.read_events(issuer: application.issuer)).to be_empty
            expect(AgencyIdentity.where(user:, agency: application.agency)).to be_empty
          end
        end
      end
    end

    describe 'billing' do
      let!(:sign_in_row) do
        create(
          :sp_return_log, user_id: user.id, issuer: service_provider.issuer, ial: 2,
                          billable: true, returned_at: Time.zone.now
        )
      end

      before do
        Billing::SignInWaiverLink.write(
          access_token: subject_token, sp_return_log_id: sign_in_row.id,
        )
      end

      it 'bills the agency for the delegated token and waives the service provider sign-in' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)

        expect { exchange }.to change { SpReturnLog.count }.by(1)

        agency_row = SpReturnLog.last
        expect(agency_row).to have_attributes(
          issuer: application.issuer, user_id: user.id, ial: 2, billable: true,
          access_type: 'delegated',
          request_id: "tx:#{grant.delegation_id}:#{application.issuer}:2"
        )
        issued = TokenExchangeToken.last
        expect(agency_row.billing_adjustments.delegated_token_issued.sole.token_exchange_token)
          .to eq(issued)
        exclusion = sign_in_row.billing_adjustments.exclude_from_billing.sole
        expect(exclusion).to have_attributes(
          delegated_return_log: agency_row, token_exchange_token: issued,
        )
        expect(exclusion).to be_resolved_via_cache
        expect(analytics).to have_logged_event(
          :delegated_billing_waiver, hash_including(outcome: 'cache_hit')
        )
      end

      it 'keeps a non-billable trail row for a second exchange under the same approval' do
        exchange
        refresh_credentials(access_token: subject_token)

        expect { exchange }.to change { SpReturnLog.count }.by(1)
        expect(response).to have_http_status(:ok)
        expect(SpReturnLog.last).to have_attributes(billable: false, access_type: 'delegated')
        expect(SpReturnLog.where(access_type: 'delegated', billable: true).count).to eq(1)
        expect(sign_in_row.billing_adjustments.exclude_from_billing.count).to eq(1)
      end

      it 'issues the token even when billing fails' do
        allow(Billing::SpReturnLogWriter).to receive(:write).and_raise(ActiveRecord::StatementInvalid)
        allow(NewRelic::Agent).to receive(:notice_error)

        expect { exchange }.to change { TokenExchangeToken.count }.by(1)
        expect(response).to have_http_status(:ok)
        expect(DelegatedTokenStore.read(json[:access_token])).to be_present
      end
    end

    describe 'the issued token' do
      it 'is refused at userinfo' do
        exchange
        get api_openid_connect_userinfo_path,
            headers: { 'HTTP_AUTHORIZATION' => "Bearer #{json[:access_token]}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'cannot be exchanged again' do
        exchange
        issued = json[:access_token]
        expect(DelegatedTokenStore.read(issued)).to be_present

        params[:subject_token] = issued
        refresh_credentials(access_token: issued)
        expect { exchange }.not_to(change { TokenExchangeToken.count })
        expect(json[:error]).to eq('invalid_grant')
      end

      it 'stops working, with its refresh token, when the approval is revoked' do
        exchange
        issued = json[:access_token]
        grant.revoke!(reason: 'user_revoked')
        expect(DelegatedTokenStore.read(issued)).to be_nil
        expect(TokenExchangeToken.last.revocation_reason).to eq('user_revoked')
        expect(TokenExchangeRefreshToken.last.revocation_reason).to eq('user_revoked')
      end
    end

    describe 'the request' do
      shared_examples 'invalid_request' do |key|
        it "fails with invalid_request (#{key})" do
          expect { exchange }.not_to(change { TokenExchangeToken.count })
          expect(TokenExchangeRefreshToken.count).to eq(0)
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_request')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
        end
      end

      context 'with a code_verifier' do
        let(:extra_params) { { code_verifier: SecureRandom.hex } }

        include_examples 'invalid_request', 'code_verifier_not_allowed'
      end

      context 'with a subject_token_type other than access_token' do
        let(:extra_params) { { subject_token_type: 'urn:ietf:params:oauth:token-type:id_token' } }

        include_examples 'invalid_request', 'invalid_subject_token_type'
      end

      context 'without a subject_token' do
        let(:subject_token) { nil }

        include_examples 'invalid_request', 'subject_token_missing'
      end

      context 'without a requested_token_type' do
        let(:requested_token_type) { nil }

        it 'issues the format the API is registered for' do
          stub_request_analytics
          exchange

          expect(response).to have_http_status(:ok)
          expect(json[:issued_token_type])
            .to eq(OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE)
          expect(@analytics).to have_logged_event(
            :openid_connect_token_exchange, hash_including(success: true)
          )
          expect(@analytics).not_to have_logged_event(
            :openid_connect_token_exchange,
            hash_including(requested_token_type_mismatch: true),
          )
        end
      end

      context 'with a requested_token_type other than the registered format' do
        let(:requested_token_type) { OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE }

        it 'issues the registered format and notes the mismatch' do
          stub_request_analytics
          exchange

          expect(response).to have_http_status(:ok)
          expect(json[:issued_token_type])
            .to eq(OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE)
          expect(TokenExchangeToken.last.token_format).to eq('oauth')
          expect(@analytics).to have_logged_event(
            :openid_connect_token_exchange,
            hash_including(
              success: true,
              requested_token_type: OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE,
              requested_token_type_mismatch: true,
            ),
          )
        end
      end

      context 'with an unknown requested_token_type' do
        let(:requested_token_type) { 'urn:ietf:params:oauth:token-type:jwt' }

        include_examples 'invalid_request', 'invalid_requested_token_type'
      end

      context 'without a resource' do
        let(:resource) { nil }

        include_examples 'invalid_request', 'resource_missing'
      end

      context 'with two resources' do
        let(:resource) { [resource_server.identifier, 'https://other.example.gov'] }

        include_examples 'invalid_request', 'multiple_resources'
      end
    end

    describe 'the subject token' do
      shared_examples 'invalid_grant' do |key|
        it "fails with invalid_grant (#{key}) and issues nothing" do
          expect { exchange }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_grant')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
        end
      end

      context 'unknown' do
        let(:subject_token) { SecureRandom.urlsafe_base64(32) }

        include_examples 'invalid_grant', 'invalid_subject_token'
      end

      context 'issued to a different service provider' do
        let(:other_sp) { create(:service_provider, :delegation_service_provider) }
        let(:subject_token) do
          IdentityLinker.new(user, other_sp)
            .link_identity(ial: 2, rails_session_id:, dpop_jkt: identity.dpop_jkt).access_token
        end

        include_examples 'invalid_grant', 'invalid_subject_token'
      end

      context 'for a connection the person revoked' do
        before { identity.update!(deleted_at: Time.zone.now) }

        include_examples 'invalid_grant', 'invalid_subject_token'
      end

      context 'when the sign-in that issued it has ended' do
        before { OutOfBandSessionAccessor.new(rails_session_id).destroy }

        include_examples 'invalid_grant', 'subject_token_session_ended'
      end

      context 'when the sign-in was at IAL1' do
        let(:identity_ial) { 1 }

        include_examples 'invalid_grant', 'identity_not_verified'
      end

      context 'when the sign-in was IALmax for an unverified person' do
        let(:identity_ial) { 0 }
        let(:user) { create(:user, :fully_registered) }

        include_examples 'invalid_grant', 'identity_not_verified'
      end

      context 'when the person no longer has an active profile' do
        before { user.active_profile.deactivate(:password_reset) }

        include_examples 'invalid_grant', 'identity_not_verified'
      end

      context 'when the person is suspended' do
        before { user.update!(suspended_at: Time.zone.now) }

        include_examples 'invalid_grant', 'user_suspended'
      end

      context 'at IALmax for a verified person' do
        let(:identity_ial) { 0 }

        it 'succeeds and forwards the stored IAL' do
          exchange
          expect(response).to have_http_status(:ok)
          expect(TokenExchangeToken.last.ial).to eq(0)
        end
      end
    end

    describe 'the resource' do
      shared_examples 'invalid_target' do |key|
        it "fails with invalid_target (#{key})" do
          expect { exchange }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_target')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
        end
      end

      context 'unregistered' do
        let(:resource) { 'https://nowhere.example.gov' }

        include_examples 'invalid_target', 'unknown_resource'
      end

      context 'when the API URL is inactive' do
        before { resource_server.update!(active: false) }

        include_examples 'invalid_target', 'unknown_resource'
      end

      context 'when the application is inactive' do
        before { application.update!(active: false) }

        include_examples 'invalid_target', 'unknown_resource'
      end

      context 'when the application does not accept this service provider' do
        before { application.update!(allowed_delegation_service_providers: ['urn:someone-else']) }

        include_examples 'invalid_target', 'unknown_resource'
      end

      context 'when the API is registered for SAML assertions' do
        before { resource_server.update!(token_format: 'saml2') }

        it 'issues the assertion: the registration decides the format' do
          exchange
          expect(response).to have_http_status(:ok)
          expect(json[:issued_token_type]).to eq(OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE)
          expect(json[:token_type]).to eq('N_A')
          expect(TokenExchangeToken.last.token_format).to eq('saml2')
        end

        context 'and the request asks for an access token' do
          let(:requested_token_type) { OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE }

          it 'still issues the assertion and notes the mismatch' do
            stub_request_analytics
            exchange

            expect(response).to have_http_status(:ok)
            expect(json[:issued_token_type])
              .to eq(OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE)
            expect(@analytics).to have_logged_event(
              :openid_connect_token_exchange,
              hash_including(success: true, requested_token_type_mismatch: true),
            )
          end
        end
      end

      context 'when the application lists this service provider' do
        before do
          application.update!(allowed_delegation_service_providers: [service_provider.issuer])
        end

        it 'succeeds' do
          exchange
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'the approval' do
      shared_examples 'consent_required' do
        it 'fails with consent_required naming the scope to request' do
          expect { exchange }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('consent_required')
          expect(json[:error_description]).to eq(
            t(
              'openid_connect.token.errors.consent_required',
              delegation_scope: 'token_exchange:housing_records',
            ),
          )
          expect(json[:error_description]).to include('token_exchange:housing_records')
        end
      end

      context 'when the person never approved the application' do
        before { grant.revoke!(reason: 'user_revoked') }

        include_examples 'consent_required'
      end

      context 'when the approval was for another application only' do
        let!(:grant) do
          TokenExchangeGrant.approve!(
            user:, service_provider:, source: 'consent_screen', remember: true,
            application: create(:service_provider, :delegation_application)
          )
        end

        include_examples 'consent_required'
      end

      context 'when a remembered approval has expired' do
        before { grant.update!(remember_until: 1.minute.ago) }

        include_examples 'consent_required'
      end

      context 'when a single-authorization approval belongs to an earlier sign-in' do
        before { grant.update!(remember_until: nil, rails_session_id: 'previous-session') }

        include_examples 'consent_required'
      end

      context 'when a single-authorization approval was given in this sign-in' do
        before { grant.update!(remember_until: nil, rails_session_id:) }

        it 'succeeds' do
          exchange
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when the agency materially changed its content since the approval' do
        before do
          application.update!(
            consent_content_version: application.consent_content_version + 1,
            consent_material_version: application.consent_material_version + 1,
          )
        end

        include_examples 'consent_required'
      end

      context 'when the approval was given to a different service provider' do
        let!(:grant) do
          TokenExchangeGrant.approve!(
            user:, application:, source: 'consent_screen', remember: true,
            service_provider: create(:service_provider, :delegation_service_provider)
          )
        end

        include_examples 'consent_required'
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
    let!(:identity) { link_identity(service_provider) }
    let(:client_assertion) do
      build_client_assertion(
        client_id: service_provider.issuer,
        audience: api_openid_connect_token_url,
      )
    end
    let(:credentials) do
      { client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE, client_assertion: }
    end

    # A second request needs a fresh assertion: the jti of the first has been used. The token
    # being presented does not enter a client assertion.
    def refresh_credentials(access_token:) # rubocop:disable Lint/UnusedMethodArgument
      params[:client_assertion] = build_client_assertion(
        client_id: service_provider.issuer, audience: api_openid_connect_token_url,
      )
    end

    include_examples 'a token exchange', token_type: 'Bearer'

    describe 'client authentication' do
      shared_examples 'invalid_client' do
        it 'fails with invalid_client and issues nothing' do
          stub_request_analytics
          expect { exchange }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description]).to be_present
          expect(@analytics).to have_logged_event(
            :openid_connect_token_exchange,
            hash_including(success: false, error_code: 'invalid_client'),
          )
        end
      end

      context 'without any credential' do
        let(:credentials) { {} }

        include_examples 'invalid_client'

        it 'says how each kind of client authenticates' do
          exchange
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.client_authentication_required'))
        end
      end

      context 'with the wrong client_assertion_type' do
        let(:credentials) do
          { client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:saml2-bearer',
            client_assertion: }
        end

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
          exchange
          expect(@analytics).to have_logged_event(
            :sp_integration_errors_present,
            hash_including(
              event: :oidc_token_exchange_request,
              integration_exists: true,
              request_issuer: service_provider.issuer,
            ),
          )
        end
      end

      context 'when the assertion was minted for a different endpoint' do
        let(:client_assertion) do
          build_client_assertion(
            client_id: service_provider.issuer, audience: api_openid_connect_userinfo_url,
          )
        end

        include_examples 'invalid_client'
      end

      context 'when the same assertion is replayed' do
        it 'accepts the first and rejects the second' do
          exchange
          expect(response).to have_http_status(:ok)
          exchange
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.client_assertion_replayed'))
        end
      end

      context 'when the client only names itself' do
        let(:credentials) { { client_id: service_provider.issuer } }

        include_examples 'invalid_client'
      end

      context 'when the client is not approved for delegation' do
        before { service_provider.update!(token_exchange_enabled_sp: false) }

        include_examples 'invalid_client'

        it 'says so' do
          exchange
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.client_not_approved'))
        end
      end

      context 'when the client is inactive' do
        before { service_provider.update!(active: false) }

        include_examples 'invalid_client'
      end

      context 'when delegated access is switched off' do
        let(:token_exchange_enabled) { false }

        it 'answers unsupported_grant_type' do
          exchange
          expect(response).to have_http_status(:bad_request)
          expect(json).to eq(
            error: 'unsupported_grant_type',
            error_description: t('openid_connect.token.errors.unsupported_grant_type'),
          )
        end
      end

      it 'withholds everything about the target from an unauthenticated caller' do
        params.delete(:client_assertion)
        params[:resource] = 'https://nowhere.example.gov'
        params[:subject_token] = 'not-a-token'
        exchange
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
    let!(:identity) { link_identity(service_provider, dpop_jkt: dpop_thumbprint) }
    let(:credentials) { { client_id: service_provider.issuer } }
    let(:headers) { { 'DPoP' => proof } }
    let(:proof) do
      build_dpop_proof(url: api_openid_connect_token_url, access_token: subject_token)
    end

    def refresh_credentials(access_token:)
      headers['DPoP'] = build_dpop_proof(url: api_openid_connect_token_url, access_token:)
    end

    include_examples 'a token exchange', token_type: 'DPoP'

    it 'binds the issued token to the proof key' do
      exchange
      issued = TokenExchangeToken.last
      expect(issued.dpop_jkt).to eq(dpop_thumbprint)
      expect(issued).to be_key_bound
      expect(DelegatedTokenStore.read(json[:access_token])[:dpop_jkt]).to eq(dpop_thumbprint)
    end

    describe 'the proof' do
      shared_examples 'invalid_dpop_proof' do |key|
        it "fails with invalid_dpop_proof (#{key}) and issues nothing" do
          stub_request_analytics
          expect { exchange }.not_to(change { TokenExchangeToken.count })
          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json[:error_description]).to eq(t("openid_connect.token.errors.#{key}"))
          expect(@analytics).to have_logged_event(
            :openid_connect_token_exchange,
            hash_including(success: false, client_type: 'public', error_code: 'invalid_dpop_proof'),
          )
        end
      end

      context 'missing' do
        let(:headers) { {} }

        include_examples 'invalid_dpop_proof', 'dpop_proof_required'
      end

      context 'signed by a key other than the one the subject token is bound to' do
        let(:proof) do
          build_dpop_proof(
            url: api_openid_connect_token_url, access_token: subject_token,
            key: OpenSSL::PKey::EC.generate('prime256v1')
          )
        end

        include_examples 'invalid_dpop_proof', 'dpop_key_mismatch'
      end

      context 'without ath over the subject token' do
        let(:proof) { build_dpop_proof(url: api_openid_connect_token_url) }

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'for another endpoint' do
        let(:proof) do
          build_dpop_proof(url: api_openid_connect_userinfo_url, access_token: subject_token)
        end

        include_examples 'invalid_dpop_proof', 'dpop_proof_invalid'
      end

      context 'replayed' do
        it 'accepts the first use and refuses the second' do
          exchange
          expect(response).to have_http_status(:ok)
          exchange
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.dpop_proof_replayed'))
        end
      end

      it 'is not accepted from the request body' do
        params[:dpop_proof] = headers.delete('DPoP')
        exchange
        expect(json[:error]).to eq('invalid_dpop_proof')
      end
    end

    describe 'client identification' do
      context 'with an unknown client_id' do
        let(:credentials) { { client_id: 'urn:gov:gsa:openidconnect:sp:nobody' } }

        it 'fails with invalid_client' do
          exchange
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
          exchange
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.client_authentication_required'))
        end
      end

      context 'when the client is not approved for delegation' do
        before { service_provider.update!(token_exchange_enabled_sp: false) }

        it 'fails with invalid_client before looking at the proof' do
          exchange
          expect(json[:error]).to eq('invalid_client')
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.client_not_approved'))
        end
      end

      context 'with a subject token issued without a key binding' do
        let!(:identity) { link_identity(service_provider) }
        let(:proof) do
          build_dpop_proof(url: api_openid_connect_token_url, access_token: subject_token)
        end

        it 'fails with invalid_grant' do
          exchange
          expect(json[:error]).to eq('invalid_grant')
        end
      end

      it 'withholds everything about the target from a caller without a proof' do
        headers.delete('DPoP')
        params[:resource] = 'https://nowhere.example.gov'
        exchange
        expect(json[:error]).to eq('invalid_dpop_proof')
      end
    end
  end

  describe 'other grant types' do
    let(:service_provider) { create(:service_provider, :delegation_service_provider) }
    let(:credentials) { {} }

    it 'still sends the authorization code grant to its own form' do
      post api_openid_connect_token_path, params: { grant_type: 'authorization_code', code: 'x' }
      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to include(t('openid_connect.token.errors.invalid_code'))
      expect(json).not_to have_key(:error_description)
    end

    it 'answers unsupported_grant_type for anything else' do
      stub_request_analytics
      post api_openid_connect_token_path,
           params: { grant_type: 'client_credentials', client_id: 'urn:gov:gsa:openidconnect:x' }
      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(
        error: 'unsupported_grant_type',
        error_description: t('openid_connect.token.errors.unsupported_grant_type'),
      )
      expect(@analytics).to have_logged_event(
        'OpenID Connect: token',
        hash_including(success: false, client_id: 'urn:gov:gsa:openidconnect:x'),
      )
    end
  end
end
