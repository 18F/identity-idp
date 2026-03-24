# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::ProfileEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#idv_intro_visit' do
    it 'logs the event' do
      analytics.idv_intro_visit
      expect(analytics).to have_logged_event('IdV: intro visited')
    end
  end

  describe '#idv_personal_key_visited' do
    it 'logs the event' do
      analytics.idv_personal_key_visited
      expect(analytics).to have_logged_event('IdV: personal key visited')
    end
  end

  describe '#idv_start_over' do
    it 'logs the event' do
      analytics.idv_start_over(step: 'welcome', location: 'top')
      expect(analytics).to have_logged_event('IdV: start over')
    end
  end

  describe '#profile_personal_key_visit' do
    it 'logs the event' do
      analytics.profile_personal_key_visit
      expect(analytics).to have_logged_event('Profile: Visited new personal key')
    end
  end
end
