# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::IdvInPersonEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#idv_in_person_location_visited' do
    it 'logs the event' do
      analytics.idv_in_person_location_visited(
        flow_path: 'standard',
        opted_in_to_in_person_proofing: nil,
      )
      expect(analytics).to have_logged_event('IdV: in person proofing location visited')
    end
  end

  describe '#idv_in_person_ready_to_verify_visit' do
    it 'logs the event' do
      analytics.idv_in_person_ready_to_verify_visit
      expect(analytics).to have_logged_event('IdV: in person ready to verify visited')
    end
  end

  describe '#idv_in_person_direct_start' do
    it 'logs the event' do
      analytics.idv_in_person_direct_start
      expect(analytics).to have_logged_event(:idv_in_person_direct_start)
    end
  end
end
