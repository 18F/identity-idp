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
      IdentityLinker.new(user, client_id).link_identity(rails_session_id: SecureRandom.hex, ial: 1)
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
        expect(@analytics).to receive(:track_event).
          with(Analytics::OPENID_CONNECT_TOKEN, success: true, client_id: client_id, errors: {})

        action
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
        expect(@analytics).to receive(:track_event).
          with(Analytics::OPENID_CONNECT_TOKEN,
               success: false,
               client_id: client_id,
               errors: hash_including(:grant_type))

        action
      end
    end
  end
end
