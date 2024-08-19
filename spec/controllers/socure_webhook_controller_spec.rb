# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST /api/webhooks/socure/event' do
    let(:socure_secret_key) { 'this-is-a-secret' }

    before do
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key).
        and_return(socure_secret_key)
    end

    it 'returns OK with a correct secret key' do
      request.headers['Authorization'] = socure_secret_key
      post :create

      expect(response).to have_http_status(:ok)
    end

    it 'returns unauthorized with a bad secret key' do
      request.headers['Authorization'] = 'ABC123'
      post :create

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized with no secret key' do
      post :create

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
