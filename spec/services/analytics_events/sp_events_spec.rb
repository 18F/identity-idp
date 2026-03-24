# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::SpEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#oidc_logout_requested' do
    it 'logs the event' do
      analytics.oidc_logout_requested(success: true)
      expect(analytics).to have_logged_event('OIDC Logout Requested')
    end
  end

  describe '#oidc_logout_visited' do
    it 'logs the event' do
      analytics.oidc_logout_visited(success: true)
      expect(analytics).to have_logged_event('OIDC Logout Page Visited')
    end
  end

  describe '#sp_redirect_initiated' do
    it 'logs the event' do
      analytics.sp_redirect_initiated(
        ial: 1,
        billed_ial: 1,
        sign_in_flow: 'password',
        acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
        sign_in_duration_seconds: 10,
      )
      expect(analytics).to have_logged_event('SP redirect initiated')
    end
  end

  describe '#saml_auth_request' do
    it 'logs the event' do
      analytics.saml_auth_request(
        requested_ial: '1',
        authn_context: [],
        requested_aal_authn_context: nil,
        force_authn: false,
        final_auth_request: true,
      )
      expect(analytics).to have_logged_event('SAML Auth Request')
    end
  end
end
