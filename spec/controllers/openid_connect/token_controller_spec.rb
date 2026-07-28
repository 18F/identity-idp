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
          }
        )

        expect(@analytics).to_not have_logged_event(:sp_integration_errors_present)
      end

      context 'when auth_time is enabled' do
        let(:authentication_event_at) { Time.zone.parse('2026-07-01 12:00:00 UTC') }
        let(:remember_device_at) { Time.zone.parse('2026-07-01 12:30:00 UTC') }
        let(:federation_at) { Time.zone.parse('2026-07-01 13:00:00 UTC') }
        let(:stale_identity_timestamp) { 1.week.before(authentication_event_at) }

        before do
          allow(FeatureManagement).to receive(:auth_time_attribute_enabled?).and_return(true)
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
end
