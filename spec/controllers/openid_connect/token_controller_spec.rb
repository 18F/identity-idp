require 'rails_helper'

RSpec.describe OpenidConnect::TokenController do
  include Rails.application.routes.url_helpers

  describe '#create' do
    subject(:action) do
      post :create,
           params: {
             grant_type: grant_type,
             code: code,
             client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
             client_assertion: client_assertion,
           }
    end

    let(:user) { create(:user) }
    let(:grant_type) { 'authorization_code' }
    let(:code) { identity.session_uuid }
    let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
    let(:service_provider) { build(:service_provider, issuer: client_id) }
    let(:client_assertion) do
      jwt_payload = {
        iss: client_id,
        sub: client_id,
        aud: api_openid_connect_token_url,
        jti: SecureRandom.hex,
        exp: 5.minutes.from_now.to_i,
      }

      client_private_key = OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)

      JWT.encode(jwt_payload, client_private_key, 'RS256')
    end

    let!(:identity) do
      IdentityLinker.new(user, service_provider).link_identity(
        acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
        ial: 1,
        rails_session_id: SecureRandom.hex,
      )
    end

    it 'adds subject token fingerprint to subject-token analytics attributes' do
      analytics_attributes = {
        token_endpoint_operation: TokenExchange::Constants::STAGE_SUBJECT_TOKEN,
      }
      response = { access_token: 'subject-token' }

      controller.send(:add_subject_token_fingerprint, analytics_attributes, response)

      expect(analytics_attributes).to include(
        subject_token_fingerprint: TokenExchange::SubjectToken.digest('subject-token'),
      )
    end

    context 'with valid params' do
      it 'is successful and has a response with the id_token' do
        action
        expect(response).to be_ok

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:id_token]).to be_present
        expect(json).to_not have_key(:error)
      end

      it 'tracks a successful event in analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: token', {
            success: true,
            client_id: client_id,
            user_id: user.uuid,
            code_digest: kind_of(String),
            code_verifier_present: false,
            expires_in: 0,
            ial: 1,
            token_endpoint_operation: 'authorization_code',
          }
        )

        expect(@analytics).to_not have_logged_event(:sp_integration_errors_present)
      end

      it 'does not track the brokered exchange token event' do
        stub_analytics

        action

        expect(@analytics).to_not have_logged_event(:openid_connect_brokered_exchange_token)
      end

      context 'with an authentication event' do
        let(:authentication_event_at) { Time.zone.parse('2026-07-01 12:00:00 UTC') }
        let(:remember_device_at) { Time.zone.parse('2026-07-01 12:30:00 UTC') }
        let(:federation_at) { Time.zone.parse('2026-07-01 13:00:00 UTC') }
        let(:stale_identity_timestamp) { 1.week.before(authentication_event_at) }

        before do
          identity.update!(last_authenticated_at: stale_identity_timestamp)

          travel_to(federation_at) do
            IdentityLinker.new(user, service_provider).link_identity(
              acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
              ial: 1,
              rails_session_id: identity.rails_session_id,
            )
          end
          identity.reload

          write_out_of_band_user_session(
            session_uuid: identity.rails_session_id,
            user_session: {
              auth_events: [
                {
                  auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
                  at: authentication_event_at,
                },
                {
                  auth_method: TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE,
                  at: remember_device_at,
                },
              ],
            },
          )
        end

        it 'returns the latest IdP authentication event instead of the federation time' do
          travel_to(federation_at) { action }

          json = JSON.parse(response.body).with_indifferent_access
          payload = JWT.decode(
            json[:id_token],
            Rails.application.config.oidc_public_key,
            true,
            algorithm: 'RS256',
          ).first.with_indifferent_access

          expect(identity.last_authenticated_at.to_i).to eq(federation_at.to_i)
          expect(payload[:auth_time]).to eq(authentication_event_at.to_i)
        end
      end
    end

    context 'with invalid params' do
      let(:grant_type) { nil }

      it 'is a 400 and has an error response and no id_token' do
        action
        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:error]).to be_present
        expect(json).to_not have_key(:id_token)
      end

      it 'tracks an unsuccessful event in analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: token', {
            success: false,
            client_id: client_id,
            user_id: user.uuid,
            code_digest: kind_of(String),
            code_verifier_present: false,
            error_details: hash_including(:grant_type),
            ial: 1,
            token_endpoint_operation: 'authorization_code',
          }
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Grant type is not included in the list',
          ),
          error_types: { grant_type: true },
          event: :oidc_token_request,
          integration_exists: true,
          request_issuer: client_id,
        )
      end
    end

    context 'with invalid form' do
      let(:code) { { nested: 'code' } }

      it 'is a 400 and has an error response and no id_token' do
        stub_analytics

        action
        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:error]).to be_present
        expect(json).to_not have_key(:id_token)

        expect(@analytics).to_not have_logged_event(:sp_integration_errors_present)
      end
    end
  end

  describe '#create with the token exchange grant type' do
    subject(:action) do
      post :create,
           params: {
             grant_type: grant_type,
             client_id: broker_issuer,
             subject_token: subject_token,
             subject_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
             requested_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
             audience: audience,
             resource: resource,
           }
    end

    let(:grant_type) { TokenExchange::Constants::GRANT_TYPE }
    let(:user) { create(:user, :proofed) }
    let(:broker_issuer) { 'broker-issuer' }
    let(:target_issuer) { 'target-issuer' }
    let(:audience) { target_issuer }
    let(:resource) { 'https://api.example.gov/passport' }
    let(:scope) { 'openid token_exchange:passport' }

    let!(:broker) { create(:service_provider, :active, issuer: broker_issuer) }
    let!(:target) { create(:service_provider, :active, issuer: target_issuer) }

    let(:identity) do
      create(
        :service_provider_identity,
        user:,
        service_provider: broker_issuer,
        scope:,
        ial: 2,
      )
    end

    let!(:target_identity) do
      create(
        :service_provider_identity,
        user:,
        service_provider: target_issuer,
        scope:,
        ial: 2,
      )
    end

    let(:actor_return_log) do
      create(
        :sp_return_log,
        user:, issuer: broker_issuer, ial: 2, billable: true, returned_at: Time.zone.now,
      )
    end
    let(:subject_token) do
      TokenExchange::SubjectTokenIssuer.issue(
        identity:, actor_return_log_id: actor_return_log.id,
      ).token
    end

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
        .and_return([broker_issuer])
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets)
        .and_return([{ issuer: target_issuer, scope: 'passport' }])
    end

    context 'with valid params' do
      it 'is successful' do
        action

        expect(response).to be_ok
      end

      it 'tracks the brokered exchange token event' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          :openid_connect_brokered_exchange_token,
          success: true,
          client_id: broker_issuer,
          audience: target_issuer,
          resource: resource,
          expires_in: IdentityConfig.store.token_exchange_access_token_expires_in,
          ial: 2,
        )
      end

      it 'does not track the authorization code token event' do
        stub_analytics

        action

        expect(@analytics).to_not have_logged_event('OpenID Connect: token')
      end

      it 'does not track service provider integration errors' do
        stub_analytics

        action

        expect(@analytics).to_not have_logged_event(:sp_integration_errors_present)
      end
    end

    context 'when the subject token is invalid' do
      let(:subject_token) { 'not-a-real-subject-token' }

      it 'is a 400 with an invalid_grant error' do
        action

        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:error]).to eq('invalid_grant')
      end

      it 'tracks an unsuccessful brokered exchange token event' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          :openid_connect_brokered_exchange_token,
          success: false,
          client_id: broker_issuer,
          audience: target_issuer,
          resource: resource,
          error_details: hash_including(:subject_token),
        )
      end

      it 'tracks service provider integration errors' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including('Subject token is invalid'),
          error_types: { subject_token: true },
          event: :oidc_token_request,
          integration_exists: true,
          request_issuer: broker_issuer,
        )
      end
    end

    context 'when the target audience is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets)
          .and_return([])
      end

      it 'is a 400 with an invalid_target error' do
        action

        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:error]).to eq('invalid_target')
      end

      it 'tracks an unsuccessful brokered exchange token event with the requested audience' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          :openid_connect_brokered_exchange_token,
          success: false,
          client_id: broker_issuer,
          audience: target_issuer,
          resource: resource,
          error_details: hash_including(:audience),
        )
      end
    end

    context 'when token exchange is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false)
      end

      it 'tracks an unsuccessful brokered exchange token event' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          :openid_connect_brokered_exchange_token,
          success: false,
          client_id: broker_issuer,
          audience: target_issuer,
          resource: resource,
          error_details: hash_including(:grant_type),
        )
      end
    end

    context 'when the broker is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
          .and_return([])
      end

      it 'is a 401 with an invalid_client error' do
        action

        expect(response).to be_unauthorized

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:error]).to eq('invalid_client')
        expect(json).to_not have_key(:access_token)
      end
    end

    context 'when a required parameter is missing' do
      let(:audience) { nil }

      it 'is a 400 with an invalid_request error' do
        action

        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access
        expect(json[:error]).to eq('invalid_request')
      end
    end
  end
end
