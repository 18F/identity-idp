require 'rails_helper'

describe Idv::CancellationsController do
  describe '#new' do
    it 'tracks the event in analytics when referer is nil' do
      stub_sign_in
      stub_analytics
      properties = { request_came_from: 'no referer' }

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_CANCELLATION, properties)

      get :new
    end

    it 'tracks the event in analytics when referer is present' do
      stub_sign_in
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'
      properties = { request_came_from: 'users/sessions#new' }

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_CANCELLATION, properties)

      get :new
    end
  end

  describe '#destroy' do
    it 'tracks an analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_CANCELLATION_CONFIRMED)

      delete :destroy
    end
  end
end
