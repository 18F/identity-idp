# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::NavigationEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#contact_redirect' do
    it 'logs the event' do
      analytics.contact_redirect(redirect_url: 'https://example.com')
      expect(analytics).to have_logged_event('Contact Page Redirect')
    end
  end

  describe '#event_disavowal' do
    it 'logs the event' do
      analytics.event_disavowal(success: true, user_id: 'abc123')
      expect(analytics).to have_logged_event('Event disavowal visited')
    end
  end

  describe '#rules_of_use_visit' do
    it 'logs the event' do
      analytics.rules_of_use_visit
      expect(analytics).to have_logged_event('Rules of Use Visited')
    end
  end

  describe '#vendor_outage' do
    it 'logs the event' do
      analytics.vendor_outage(vendor_status: {})
      expect(analytics).to have_logged_event('Vendor Outage')
    end
  end

  describe '#session_timed_out' do
    it 'logs the event' do
      analytics.session_timed_out
      expect(analytics).to have_logged_event('Session Timed Out')
    end
  end
end
