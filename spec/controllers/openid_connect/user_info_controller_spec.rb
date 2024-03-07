require 'rails_helper'

RSpec.describe OpenidConnect::UserInfoController, allowed_extra_analytics: [:*] do
  let(:json_response) { JSON.parse(response.body).with_indifferent_access }

  describe '#show' do
    subject(:action) do
      request.headers['HTTP_AUTHORIZATION'] = authorization_header
      post :show, params: params
    end

    let(:params) { {} }

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
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      end

      context 'without a vtr param' do
        it 'renders user info without a vtr key' do
          action
          expect(response).to be_ok
          expect(json_response).not_to have_key(:vtr)
        end

        it 'renders user info with an ial key' do
          action
          expect(response).to be_ok
          expect(json_response).to have_key(:ial)
        end

        it 'renders user info with an aal key' do
          action
          expect(response).to be_ok
          expect(json_response).to have_key(:aal)
        end
      end

      context 'with a vtr param' do
        let(:params) { { vtr: 'C1' } }

        it 'renders user info with a vtr key' do
          action
          expect(json_response).to have_key(:vtr)
        end

        it 'renders user info without an ial key' do
          action
          expect(json_response).not_to have_key(:ial)
        end

        it 'renders user info without an aal key' do
          action
          expect(json_response).not_to have_key(:aal)
        end
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
          'events' => { 'OpenID Connect: bearer token authentication' => true },
          'first_event' => true,
        }
        expect(request.session.to_h).to eq(session_hash)
      end
    end
  end
end
