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
          errors: hash_including(:access_token),
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token No Authorization header provided',
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
          errors: hash_including(:access_token),
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token Malformed Authorization header',
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
          errors: hash_including(:access_token),
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token Could not find authorization for the contents of the provided ' \
              'access_token or it may have expired',
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
          errors: { access_token: [t('openid_connect.user_info.errors.not_found')] },
          error_details: { access_token: { not_found: true } },
        )
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
