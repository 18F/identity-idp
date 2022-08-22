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
    let(:user) { create(:user) }

    before do
      stub_sign_in(user)
      stub_analytics
      stub_attempts_tracker
      allow(@irs_attempts_api_tracker).to receive(:track_event)
    end

    it 'tracks analytics events' do
      expect(@analytics).to receive(:track_event).with('IdV: forgot password confirmed')

      post :update

      expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
        :forgot_password_email_sent,
        email: user.email,
        success: true,
        failure_reason: nil,
      )
    end
  end
end
