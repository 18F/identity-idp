# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST #create' do
    it 'returns OK' do
      post :create
      expect(response).to have_http_status(:ok)
    end
  end
end
