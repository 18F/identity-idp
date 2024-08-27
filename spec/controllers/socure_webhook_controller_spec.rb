# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST /api/webhooks/socure/event' do
    let(:socure_secret_key) { 'this-is-a-secret' }
    let(:socure_secret_key_queue) { ['this-is-an-old-secret', 'this-is-an-older-secret'] }
    let(:socure_webhook_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key).
        and_return(socure_secret_key)
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key_queue).
        and_return(socure_secret_key_queue)
      allow(IdentityConfig.store).to receive(:socure_webhook_enabled).
        and_return(socure_webhook_enabled)
      Rails.application.reload_routes!
    end

    it 'returns OK with a correct secret key' do
      request.headers['Authorization'] = socure_secret_key
      post :create

      expect(response).to have_http_status(:ok)
    end

    it 'returns OK with an older secret key' do
      request.headers['Authorization'] = socure_secret_key_queue.last
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

    context 'when socure webhook disabled' do
      let(:socure_webhook_enabled) { false }
      it 'the webhook route does not exist' do
        request.headers['Authorization'] = socure_secret_key
        expect{ post :create }.to raise_error(ActionController::UrlGenerationError)
      end
    end
  end
end
