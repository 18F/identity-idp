# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::IdvEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#idv_address_visit' do
    it 'logs the event' do
      analytics.idv_address_visit
      expect(analytics).to have_logged_event('IdV: address visited')
    end
  end

  describe '#idv_address_submitted' do
    it 'logs the event' do
      analytics.idv_address_submitted(success: true)
      expect(analytics).to have_logged_event('IdV: address submitted')
    end
  end

  describe '#idv_cancellation_visited' do
    it 'logs the event' do
      analytics.idv_cancellation_visited(step: 'document_capture', request_came_from: nil)
      expect(analytics).to have_logged_event('IdV: cancellation visited')
    end
  end

  describe '#idv_forgot_password' do
    it 'logs the event' do
      analytics.idv_forgot_password
      expect(analytics).to have_logged_event('IdV: forgot password')
    end
  end

  describe '#proofing_address_result_missing' do
    it 'logs the event' do
      analytics.proofing_address_result_missing
      expect(analytics).to have_logged_event(:proofing_address_result_missing)
    end
  end
end
