require 'rails_helper'

RSpec.describe OpenidConnect::UserInfoController do
  let(:json_response) { JSON.parse(response.body).with_indifferent_access }

  describe '#show' do
    subject(:action) do
      request.headers['HTTP_AUTHORIZATION'] = authorization_header
      post :show
    end

    context 'without an authorization header' do
      let(:authorization_header) { nil }

      it '401s' do
        action
        expect(response).to be_unauthorized
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          success: false,
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token No Authorization header provided. Please see our documentation at ' \
            'https://developers.login.gov/support/#no-auth-header',
          ),
          error_types: { access_token: true },
          event: :oidc_bearer_token_auth,
          integration_exists: false,
        )
      end
    end

    context 'with a malformed authorization header' do
      let(:authorization_header) { 'Boooorer ABCDEF' }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error])
          .to eq(t('openid_connect.user_info.errors.malformed_authorization'))
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          success: false,
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token Malformed Authorization header. Please see our documentation at ' \
            'https://developers.login.gov/support/#malformed-auth-header',
          ),
          error_types: { access_token: true },
          event: :oidc_bearer_token_auth,
          integration_exists: false,
        )
      end
    end

    context 'with an invalid bearer token' do
      let(:authorization_header) { 'Bearer ABCDEF' }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error]).to be_present
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          success: false,
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token Could not find authorization for the contents of the provided ' \
              'access_token or it may have expired. Please see our documentation at ' \
              'https://developers.login.gov/support/#auth-header-contents-not-found',
          ),
          error_types: { access_token: true },
          event: :oidc_bearer_token_auth,
          integration_exists: false,
        )
      end
    end

    context 'with a bearer token for an expired session' do
      let(:access_token) { SecureRandom.urlsafe_base64 }
      let(:rails_session_id) { 'missing-session-id' } # Emulate expired by missing, which has no TTL
      let!(:identity) { create(:service_provider_identity, access_token:, rails_session_id:) }
      let(:authorization_header) { "Bearer #{access_token}" }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error]).to eq(t('openid_connect.user_info.errors.not_found'))
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          success: false,
          error_details: { access_token: { not_found: true } },
        )
      end
    end

    context 'with a token of a client listed for key binding' do
      let(:service_provider) do
        create(:service_provider, :active, issuer: 'bound-client', pkce: true)
      end
      let(:access_token) { SecureRandom.hex }
      let(:identity) do
        create(
          :service_provider_identity,
          service_provider: service_provider.issuer,
          rails_session_id: SecureRandom.hex,
          access_token:,
          user: create(:user),
        )
      end
      let(:url) { 'http://www.example.com/api/openid_connect/userinfo' }
      let(:authorization_header) { "DPoP #{access_token}" }

      before do
        allow(IdentityConfig.store).to receive(:dpop_required_issuers)
          .and_return([service_provider.issuer])
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
        AccessTokenBinding.store(access_token:, dpop_jkt: dpop_thumbprint, expires_in: 50)
      end

      context 'under the DPoP scheme with a proof from the bound key' do
        before do
          request.headers['DPoP'] =
            build_dpop_proof(http_url: url, http_method: 'POST', access_token:)
        end

        it 'renders user info' do
          action
          expect(response).to be_ok
          expect(json_response[:sub]).to eq(identity.uuid)
        end
      end

      context 'presented as a Bearer token' do
        let(:authorization_header) { "Bearer #{access_token}" }

        it '401s with a DPoP challenge' do
          action
          expect(response.status).to eq(401)
          expect(response.headers['WWW-Authenticate']).to eq(
            'DPoP algs="ES256 RS256", error="invalid_token"',
          )
          expect(json_response[:error]).to eq(
            'dpop_bearer_presented',
          )
        end
      end

      context 'under the DPoP scheme without a proof' do
        it '401s as an invalid proof' do
          action
          expect(response.status).to eq(401)
          expect(response.headers['WWW-Authenticate']).to eq(
            'DPoP algs="ES256 RS256", error="invalid_dpop_proof"',
          )
          expect(json_response[:error]).to eq('dpop_proof_missing')
        end
      end
    end

    context 'with a valid bearer token' do
      let(:authorization_header) { "Bearer #{access_token}" }
      let(:access_token) { SecureRandom.hex }
      let(:identity) do
        create(
          :service_provider_identity, rails_session_id: SecureRandom.hex,
                                      access_token: access_token, user: create(:user)
        )
      end
      before do
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      end

      it 'renders user info' do
        action
        expect(response).to be_ok
        expect(json_response[:sub]).to eq(identity.uuid)
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          success: true,
          client_id: identity.service_provider,
          ial: identity.ial,
          encrypted: false,
        )

        expect(@analytics).to_not have_logged_event(
          :sp_integration_errors_present,
        )
      end

      it 'only changes the paths visited in session' do
        action
        session_hash = {
          'events' => { 'OpenID Connect: bearer token authentication' => true },
          'first_event' => true,
        }
        expect(request.session.to_h).to eq(session_hash)
      end

      context 'when document image sharing is authorized but artifacts have not landed' do
        let(:user) { create(:user) }
        let(:identity) do
          create(
            :service_provider_identity,
            rails_session_id: SecureRandom.hex,
            access_token:,
            user:,
            scope: 'openid document_images',
            acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
            biometric_sharing_consent_at: Time.zone.now,
          )
        end

        before do
          create(:profile, :active, user:, verified_at: 1.hour.ago)
          allow(IdentityConfig.store).to receive(:document_images_sharing_enabled)
            .and_return(true)
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([identity.service_provider])
        end

        it 'serializes an empty document_images object through to the JSON response' do
          action

          expect(response).to be_ok
          expect(json_response).to have_key(:document_images)
          expect(json_response[:document_images]).to eq({})
        end
      end

      context 'with an authentication event' do
        let(:authentication_event_at) { Time.zone.parse('2026-07-01 12:00:00 UTC') }
        let(:remember_device_at) { Time.zone.parse('2026-07-01 12:30:00 UTC') }
        let(:federation_at) { Time.zone.parse('2026-07-01 13:00:00 UTC') }

        before do
          identity.update!(last_authenticated_at: federation_at)
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

        it 'returns the latest IdP authentication event instead of the identity timestamp' do
          action

          expect(json_response[:auth_time]).to eq(authentication_event_at.to_i)
        end
      end

      context 'with session expiring after validation and before render' do
        before do
          allow_any_instance_of(AccessTokenVerifier).to receive(:submit).and_wrap_original do |impl|
            result = impl.call
            OutOfBandSessionAccessor.new(identity.rails_session_id).destroy
            result
          end
        end

        it 'renders user info' do
          action
          expect(response).to be_ok
          expect(json_response[:sub]).to eq(identity.uuid)
        end
      end
    end
  end
end
