require 'rails_helper'

RSpec.describe 'GPO verification routes' do
  let(:get_routes) do
    %w[
      verify/by_mail/request_letter
    ]
  end

  let(:put_routes) do
    %w[
      verify/by_mail/request_letter
    ]
  end

  before do
    allow(FeatureManagement).to receive(:gpo_verification_enabled?)
      .and_return(enable_gpo_verification)
    Rails.application.reload_routes!
  end

  context 'when enable_gpo_verification is false' do
    let(:enable_gpo_verification) { false }

    after(:all) do
      Rails.application.reload_routes!
    end

    it 'does not route to endpoints controlled by feature flag' do
      get_routes.each do |route|
        expect(get: route)
          .to route_to(controller: 'pages', action: 'page_not_found', path: route)
      end

      put_routes.each do |route|
        expect(put: route)
          .to route_to(controller: 'pages', action: 'page_not_found', path: route)
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
        expect(get: route).to route_to(controller: 'idv/by_mail/request_letter', action: 'index')
      end

      put_routes.each do |route|
        expect(put: route).to route_to(controller: 'idv/by_mail/request_letter', action: 'create')
      end
    end
  end
end
