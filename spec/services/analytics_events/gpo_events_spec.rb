# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::GpoEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#idv_gpo_address_letter_requested' do
    it 'logs the event' do
      analytics.idv_gpo_address_letter_requested(
        resend: false,
        phone_step_attempts: 0,
        first_letter_requested_at: nil,
        hours_since_first_letter: nil,
      )
      expect(analytics).to have_logged_event('IdV: USPS address letter requested')
    end
  end

  describe '#idv_letter_enqueued_visit' do
    it 'logs the event' do
      analytics.idv_letter_enqueued_visit
      expect(analytics).to have_logged_event('IdV: letter enqueued visited')
    end
  end

  describe '#idv_request_letter_visited' do
    it 'logs the event' do
      analytics.idv_request_letter_visited
      expect(analytics).to have_logged_event('IdV: request letter visited')
    end
  end

  describe '#idv_gpo_expired' do
    it 'logs the event' do
      analytics.idv_gpo_expired(user_id: 1, user_has_active_profile: false, letters_sent: 1)
      expect(analytics).to have_logged_event(:idv_gpo_expired)
    end
  end
end
