require 'rails_helper'

describe Idv::ForgotPasswordController do
  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#new' do
    before do
      stub_sign_in
      stub_analytics

      allow(@analytics).to receive(:track_event)
    end

    it 'tracks the event in analytics when referer is nil' do
      get :new

      expect(@analytics).to have_received(:track_event).with('IdV: forgot password visited')
    end
  end

  describe '#update' do
    let(:user) { create(:user) }

    before do
      stub_sign_in(user)
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
    end

    it 'tracks appropriate events' do
      expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_sent).with(
        email: user.email,
      )

      post :update

      expect(@analytics).to have_received(:track_event).with('IdV: forgot password confirmed')
    end
  end
end
