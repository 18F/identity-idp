# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::FraudEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#automatic_fraud_rejection' do
    it 'logs the event' do
      analytics.automatic_fraud_rejection(fraud_rejection_at: Time.zone.now)
      expect(analytics).to have_logged_event('Fraud: Automatic Fraud Rejection')
    end
  end

  describe '#fraud_review_passed' do
    it 'logs the event' do
      analytics.fraud_review_passed(
        success: true,
        errors: {},
        exception: nil,
        profile_fraud_review_pending_at: nil,
        profile_age_in_seconds: 100,
      )
      expect(analytics).to have_logged_event('Fraud: Profile review passed')
    end
  end

  describe '#fraud_review_rejected' do
    it 'logs the event' do
      analytics.fraud_review_rejected(
        success: true,
        errors: {},
        exception: nil,
        profile_fraud_review_pending_at: nil,
        profile_age_in_seconds: 100,
      )
      expect(analytics).to have_logged_event('Fraud: Profile review rejected')
    end
  end

  describe '#device_profiling_failed_visited' do
    it 'logs the event' do
      analytics.device_profiling_failed_visited
      expect(analytics).to have_logged_event(:device_profiling_failed_visited)
    end
  end
end
