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
        expect(@analytics).to receive(:track_event).
          with('OpenID Connect: bearer token authentication',
               success: false,
               client_id: nil,
               ial: nil,
               errors: hash_including(:access_token),
               error_details: hash_including(:access_token))

        action
      end
    end

    context 'with a malformed authorization header' do
      let(:authorization_header) { 'Boooorer ABCDEF' }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error]).
          to eq(t('openid_connect.user_info.errors.malformed_authorization'))
      end

      it 'tracks analytics' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('OpenID Connect: bearer token authentication',
               success: false,
               client_id: nil,
               ial: nil,
               errors: hash_including(:access_token),
               error_details: hash_including(:access_token))

        action
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
        expect(@analytics).to receive(:track_event).
          with('OpenID Connect: bearer token authentication',
               success: false,
               errors: hash_including(:access_token),
               client_id: nil,
               ial: nil,
               error_details: hash_including(:access_token))

        action
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
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii({}, 50)
      end

      it 'renders user info' do
        action
        expect(response).to be_ok
        expect(json_response[:sub]).to eq(identity.uuid)
      end

      it 'tracks analytics' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          'OpenID Connect: bearer token authentication',
          success: true,
          client_id: identity.service_provider,
          ial: identity.ial,
          errors: {},
        )

        action
      end

      it 'only changes the paths visited in session' do
        action
        session_hash = {
          'paths_visited' => { '/api/openid_connect/userinfo' => true },
          'first_path_visit' => true,
          'events' => { 'OpenID Connect: bearer token authentication' => true },
          'first_event' => true,
          'first_success_state' => true,
          'success_states' => {
            'POST|/api/openid_connect/userinfo|OpenID Connect: bearer token authentication' => true,
          },
        }
        expect(request.session.to_h).to eq(session_hash)
      end
    end
  end
end
