require 'rails_helper'

describe Idv::CancellationsController do
  describe '#new' do
    it 'tracks an analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_CANCELLATION)

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
