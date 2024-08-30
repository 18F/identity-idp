require 'rails_helper'

RSpec.describe Idv::ForgotPasswordController do
  describe 'before_actions' do
    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#new' do
    before do
      stub_sign_in
      stub_analytics
    end

    it 'tracks the event in analytics when referer is nil' do
      get :new

      expect(@analytics).to have_logged_event('IdV: forgot password visited')
    end
  end

  describe '#update' do
    let(:user) { create(:user) }

    before do
      stub_sign_in(user)
      stub_analytics
    end

    it 'tracks appropriate events' do
      post :update

      expect(@analytics).to have_logged_event('IdV: forgot password confirmed')
    end
  end
end
