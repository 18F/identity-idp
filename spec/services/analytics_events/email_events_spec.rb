# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::EmailEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#add_email_confirmation' do
    it 'logs the event' do
      analytics.add_email_confirmation(success: true)
      expect(analytics).to have_logged_event('Add Email: Email Confirmation')
    end
  end

  describe '#add_email_request' do
    it 'logs the event' do
      analytics.add_email_request(success: true)
      expect(analytics).to have_logged_event('Add Email Requested')
    end
  end

  describe '#add_email_visit' do
    it 'logs the event' do
      analytics.add_email_visit
      expect(analytics).to have_logged_event('Add Email Address Page Visited')
    end
  end

  describe '#email_deletion_request' do
    it 'logs the event' do
      analytics.email_deletion_request
      expect(analytics).to have_logged_event('Email Deletion Requested')
    end
  end

  describe '#email_sent' do
    it 'logs the event' do
      analytics.email_sent(action: 'add_email', ses_message_id: nil, email_address_id: 1)
      expect(analytics).to have_logged_event('Email Sent')
    end
  end
end
