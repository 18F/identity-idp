require 'rails_helper'

describe AnalyticsController do
  describe '#create' do
    before do
      stub_sign_in
      stub_analytics
    end

    it 'logs true for platform authenticator' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::PLATFORM_AUTHENTICATOR, errors: {}, success: 'true')

      post :create, params: { available: true }
    end

    it 'logs false for platform authenticator' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::PLATFORM_AUTHENTICATOR, errors: {}, success: 'false')

      post :create, params: { available: false }
    end

    it 'logs once per session' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::PLATFORM_AUTHENTICATOR, errors: {}, success: 'true')

      post :create, params: { available: true }
      post :create, params: { available: true }
    end
  end
end
