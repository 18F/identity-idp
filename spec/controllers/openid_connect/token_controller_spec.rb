require 'rails_helper'

RSpec.describe OpenidConnect::TokenController do
  include Rails.application.routes.url_helpers

  describe '#create' do
    subject(:action) do
      post :create,
           grant_type: grant_type,
           code: code,
           client_id: client_id,
           client_secret: service_provider.metadata[:client_secret],
           redirect_url: service_provider.metadata[:redirect_url]
    end

    let(:user) { create(:user) }
    let(:grant_type) { 'authorization_code' }
    let(:code) { SecureRandom.hex }
    let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
    let(:service_provider) { ServiceProvider.new(client_id) }

    before do
      IdentityLinker.new(user, client_id).link_identity(session_uuid: code, ial: 1)
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
