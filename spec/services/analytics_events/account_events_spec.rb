# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::AccountEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#account_visit' do
    it 'logs the event' do
      analytics.account_visit
      expect(analytics).to have_logged_event('Account Page Visited')
    end
  end

  describe '#add_phone_setup_visit' do
    it 'logs the event' do
      analytics.add_phone_setup_visit
      expect(analytics).to have_logged_event('Phone Setup Visited')
    end
  end

  describe '#backup_code_created' do
    it 'logs the event' do
      analytics.backup_code_created
      expect(analytics).to have_logged_event('Backup Code Created')
    end
  end

  describe '#broken_personal_key_regenerated' do
    it 'logs the event' do
      analytics.broken_personal_key_regenerated
      expect(analytics).to have_logged_event('Broken Personal Key: Regenerated')
    end
  end

  describe '#events_visit' do
    it 'logs the event' do
      analytics.events_visit
      expect(analytics).to have_logged_event('Events Page Visited')
    end
  end
end
