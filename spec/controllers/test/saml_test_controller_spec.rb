require 'rails_helper'

RSpec.describe Test::SamlTestController do
  describe 'the test-only guard' do
    it 'answers 404 outside the development and test environments' do
      allow(Rails.env).to receive(:local?).and_return(false)

      get :index

      expect(response.status).to eq(404)
    end

    it 'answers 404 when test routes are disabled' do
      allow(IdentityConfig.store).to receive(:enable_test_routes).and_return(false)

      get :index

      expect(response.status).to eq(404)
    end
  end
end
