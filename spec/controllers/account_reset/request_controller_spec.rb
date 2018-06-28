require 'rails_helper'

describe AccountReset::RequestController do
  describe '#show' do
    it 'renders the page' do
      sign_in_before_2fa

      get :show

      expect(response).to render_template(:show)
    end

    it 'redirects to root without 2fa' do
      get :show

      expect(response).to redirect_to root_url
    end

    it 'redirects to phone setup url if 2fa not setup' do
      user = create(:user)
      sign_in_before_2fa(user)
      get :show

      expect(response).to redirect_to phone_setup_url
    end
  end

  describe '#create' do
    it 'logs the request in the analytics' do
      TwilioService.telephony_service = FakeSms
      sign_in_before_2fa

      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, {event: :request})

      post :create
    end

    it 'redirects to root without 2fa' do
      post :create

      expect(response).to redirect_to root_url
    end
  end
end
