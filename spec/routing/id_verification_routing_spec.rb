require 'rails_helper'

describe 'Identity Verification Routes', type: :routing do
  GET_ROUTES = %w[
    idv
    idv/activated
    idv/address
    idv/cancel
    idv/confirmations
    idv/fail
    idv/phone
    idv/review
    idv/session
    idv/session/dupe
  ].freeze

  PUT_ROUTES = %w[
    idv/phone
    idv/review
    idv/session
  ].freeze

  DELETE_ROUTES = %w[
    idv/session
  ].freeze

  context 'when FeatureManagement.enable_identity_verification? is false' do
    before do
      allow(Figaro.env).to receive(:enable_identity_verification).and_return('false')
      Rails.application.reload_routes!
    end

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'does not route to any GET /idv/* endpoint' do
      GET_ROUTES.each do |route|
        expect(get: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end
    end

    it 'does not route to any PUT /idv/* endpoint' do
      PUT_ROUTES.each do |route|
        expect(put: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end
    end

    it 'does not route to any DELETE /idv/* endpoint' do
      DELETE_ROUTES.each do |route|
        expect(delete: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end
    end
  end

  context 'when FeatureManagement.enable_identity_verification? is true' do
    before do
      allow(Figaro.env).to receive(:enable_identity_verification).and_return('true')
      Rails.application.reload_routes!
    end

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'routes to all GET /idv/* endpoints' do
      GET_ROUTES.each do |route|
        expect(get: route).to be_routable
      end
    end

    it 'routes to all PUT /idv/* endpoints' do
      PUT_ROUTES.each do |route|
        expect(put: route).to be_routable
      end
    end

    it 'routes to all DELETE /idv/* endpoints' do
      DELETE_ROUTES.each do |route|
        expect(delete: route).to be_routable
      end
    end
  end
end
