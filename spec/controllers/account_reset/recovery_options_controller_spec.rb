require 'rails_helper'

RSpec.describe AccountReset::RecoveryOptionsController do
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

      get :show

      expect(@analytics).to have_logged_event('Account Reset: Recovery Options Visited')
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

      post :cancel

      expect(@analytics).to have_logged_event('Account Reset: Cancel Account Recovery Options')
    end
  end
end
