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
          with(Analytics::OPENID_CONNECT_BEARER_TOKEN,
               success: false, errors: hash_including(:id_token))

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
          with(Analytics::OPENID_CONNECT_BEARER_TOKEN,
               success: false, errors: hash_including(:id_token))

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
          with(Analytics::OPENID_CONNECT_BEARER_TOKEN,
               success: false, errors: hash_including(:id_token))

        action
      end
    end

    context 'with a valid bearer token' do
      let(:authorization_header) { "Bearer #{id_token}" }
      let(:id_token) { SecureRandom.hex }
      let(:identity) { build(:identity, user: build(:user)) }

      before do
        fake_verifier = instance_double(IdTokenVerifier,
                                        identity: identity,
                                        submit: FormResponse.new(success: true, errors: {}))
        expect(IdTokenVerifier).to receive(:new).
          with(authorization_header).and_return(fake_verifier)
      end

      it 'renders user info' do
        action
        expect(response).to be_ok
        expect(json_response[:sub]).to eq(identity.uuid)
      end

      it 'tracks analytics' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::OPENID_CONNECT_BEARER_TOKEN, success: true, errors: {})

        action
      end
    end
  end
end
