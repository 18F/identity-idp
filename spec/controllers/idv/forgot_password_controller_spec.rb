require 'rails_helper'

describe Idv::ForgotPasswordController do
  describe '#new' do
    it 'tracks the event in analytics when referer is nil' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_FORGOT_PASSWORD)

      get :new
    end
  end

  describe '#update' do
    it 'tracks an analytics event' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_FORGOT_PASSWORD_CONFIRMED)

      post :update
    end
  end
end
