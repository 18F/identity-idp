require 'rails_helper'

describe AccountReset::RecoveryOptionsController do
  let(:user) { create(:user, :with_authentication_app) }
  describe '#show' do
    it 'renders the page' do
      stub_sign_in_before_2fa(user)

      get :show

      expect(response).to render_template(:show)
    end

    it 'redirects to root if user not signed in' do
      get :show

      expect(response).to redirect_to root_url
    end

    it 'logs the visit to analytics' do
      stub_sign_in_before_2fa(user)
      stub_analytics

      expect(@analytics).to receive(:track_event).with('Account Reset: Recovery Options Visited')

      get :show
    end
  end

  describe '#cancel' do
    it 'redirects to 2FA options page' do
      stub_sign_in_before_2fa(user)

      post :cancel

      expect(response).to redirect_to(login_two_factor_options_url)
    end

    it 'logs the visit to analytics' do
      stub_sign_in_before_2fa(user)
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('Account Reset: Cancel Account Recovery Options')

      post :cancel
    end
  end
end
