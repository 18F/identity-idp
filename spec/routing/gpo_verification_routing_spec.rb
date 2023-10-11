require 'rails_helper'

RSpec.describe 'GPO verification routes' do
  let(:get_routes) do
    %w[
      verify/usps
    ]
  end

  let(:create_routes) do
    %w[
      verify/usps
    ]
  end

  let(:put_routes) do
    %w[
      verify/usps
    ]
  end

  before do
    allow(FeatureManagement).to receive(:gpo_verification_enabled?).
      and_return(enable_gpo_verification)
    Rails.application.reload_routes!
  end

  context 'when enable_gpo_verification is false' do
    let(:enable_gpo_verification) { false }

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'does not route to endpoints controlled by feature flag' do
      get_routes.each do |route|
        expect(get: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end

      create_routes.each do |route|
        expect(post: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end

      put_routes.each do |route|
        expect(put: route).
          to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end
    end
  end

  context 'when enable_gpo_verification is true' do
    let(:enable_gpo_verification) { true }

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'routes to endpoints controlled by feature flag' do
      get_routes.each do |route|
        expect(get: route).to be_routable
      end

      create_routes.each do |route|
        expect(post: route).to be_routable
      end

      put_routes.each do |route|
        expect(put: route).to be_routable
      end
    end
  end
end
