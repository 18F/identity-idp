# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::AuthenticationEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#authentication_confirmation' do
    it 'logs the event' do
      analytics.authentication_confirmation
      expect(analytics).to have_logged_event('Authentication Confirmation')
    end
  end

  describe '#sign_in_page_visit' do
    it 'logs the event' do
      analytics.sign_in_page_visit(flash: nil)
      expect(analytics).to have_logged_event('Sign in page visited')
    end
  end

  describe '#password_reset_visit' do
    it 'logs the event' do
      analytics.password_reset_visit
      expect(analytics).to have_logged_event('Password Reset: Email Form Visited')
    end
  end

  describe '#logout_initiated' do
    it 'logs the event' do
      analytics.logout_initiated
      expect(analytics).to have_logged_event('Logout Initiated')
    end
  end

  describe '#totp_setup_visit' do
    it 'logs the event' do
      analytics.totp_setup_visit(
        user_signed_up: true,
        totp_secret_present: true,
        enabled_mfa_methods_count: 0,
      )
      expect(analytics).to have_logged_event('TOTP Setup Visited')
    end
  end
end
