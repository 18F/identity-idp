# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::AccountResetEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#account_delete_submitted' do
    it 'logs the event' do
      analytics.account_delete_submitted(success: true)
      expect(analytics).to have_logged_event('Account Delete submitted')
    end
  end

  describe '#account_delete_visited' do
    it 'logs the event' do
      analytics.account_delete_visited
      expect(analytics).to have_logged_event('Account Delete visited')
    end
  end

  describe '#account_deletion' do
    it 'logs the event' do
      analytics.account_deletion(request_came_from: 'sign_in')
      expect(analytics).to have_logged_event('Account Deletion Requested')
    end
  end

  describe '#account_reset_visit' do
    it 'logs the event' do
      analytics.account_reset_visit
      expect(analytics).to have_logged_event('Account deletion and reset visited')
    end
  end

  describe '#pending_account_reset_visited' do
    it 'logs the event' do
      analytics.pending_account_reset_visited
      expect(analytics).to have_logged_event('Pending account reset visited')
    end
  end
end
