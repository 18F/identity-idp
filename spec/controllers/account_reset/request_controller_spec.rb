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
  end
end
