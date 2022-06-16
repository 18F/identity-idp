require 'rails_helper'

describe Idv::ForgotPasswordController do
  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#new' do
    it 'tracks the event in analytics when referer is nil' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with('IdV: forgot password visited')

      get :new
    end
  end

  describe '#update' do
    it 'tracks an analytics event' do
      user = create(:user)
      stub_sign_in(user)
      stub_analytics

      expect(@analytics).to receive(:track_event).with('IdV: forgot password confirmed')

      post :update
    end
  end
end
