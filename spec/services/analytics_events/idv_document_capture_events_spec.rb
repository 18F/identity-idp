# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsEvents::IdvDocumentCaptureEvents do
  let(:analytics) { FakeAnalytics.new }

  describe '#doc_auth_warning' do
    it 'logs the event' do
      analytics.doc_auth_warning
      expect(analytics).to have_logged_event('Doc Auth Warning')
    end
  end

  describe '#idv_doc_auth_welcome_visited' do
    it 'logs the event' do
      analytics.idv_doc_auth_welcome_visited(step: 'welcome', analytics_id: 'idv')
      expect(analytics).to have_logged_event('IdV: doc auth welcome visited')
    end
  end

  describe '#idv_doc_auth_agreement_visited' do
    it 'logs the event' do
      analytics.idv_doc_auth_agreement_visited(step: 'agreement', analytics_id: 'idv')
      expect(analytics).to have_logged_event('IdV: doc auth agreement visited')
    end
  end

  describe '#idv_camera_info_error' do
    it 'logs the event' do
      analytics.idv_camera_info_error(error: 'no camera')
      expect(analytics).to have_logged_event(:idv_camera_info_error)
    end
  end
end
