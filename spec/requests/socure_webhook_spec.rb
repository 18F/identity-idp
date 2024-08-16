# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST /api/webhooks/socure/event' do
    it 'returns OK' do
      post '/api/webhooks/socure/event'
      expect(response).to have_http_status(:ok)
    end
  end
end
