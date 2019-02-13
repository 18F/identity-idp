require 'rails_helper'

describe 'USPS verification routes' do
  GET_ROUTES = %w[
    account/verify
    verify/usps
  ].freeze

  CREATE_ROUTES = %w[
    account/verify
  ].freeze

  PUT_ROUTES = %w[
    verify/usps
  ].freeze

  context 'when FeatureManagement.enable_usps_verification? is false' do
    before do
      allow(Figaro.env).to receive(:enable_usps_verification).and_return('false')
      Rails.application.reload_routes!
    end

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'does not route to endpoints controlled by feature flag' do
      GET_ROUTES.each do |route|
        expect(get: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end

      CREATE_ROUTES.each do |route|
        expect(post: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end

      PUT_ROUTES.each do |route|
        expect(put: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end
    end
  end

  context 'when FeatureManagement.enable_usps_verification? is true' do
    before do
      allow(Figaro.env).to receive(:enable_usps_verification).and_return('true')
      Rails.application.reload_routes!
    end

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'routes to endpoints controlled by feature flag' do
      GET_ROUTES.each do |route|
        expect(get: route).to be_routable
      end

      CREATE_ROUTES.each do |route|
        expect(post: route).to be_routable
      end

      PUT_ROUTES.each do |route|
        expect(put: route).to be_routable
      end
    end
  end
end
