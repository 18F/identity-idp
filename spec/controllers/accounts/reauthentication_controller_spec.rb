require 'rails_helper'

RSpec.describe Accounts::ReauthenticationController do
  let(:user) { create(:user, :fully_registered) }

  describe '#create' do
    before(:each) do
      stub_sign_in(user)
    end
    it 'redirects to 2FA options' do
      post :create

      expect(response).to redirect_to login_two_factor_options_url(reauthn: true)
    end

    it 'sets context to authentication' do
      post :create

      expect(controller.user_session[:context]).to eq 'reauthentication'
    end

    it 'sets stored location for redirecting' do
      post :create

      expect(controller.user_session[:stored_location]).to eq account_url
    end
  end
end
