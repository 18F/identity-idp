require 'rails_helper'

RSpec.describe Test::PushNotificationController do
  before do
    allow(IdentityConfig.store).to receive(:risc_notifications_local_enabled).and_return(true)
  end
  describe '#index' do
    it 'sets @events and renders' do
      PushNotification::LocalEventQueue.events << {
        url: 'test',
        payload: 'payload',
        jwt: 'jwt',
      }
      get :index

      expect(assigns(:events).length).to eq(1)
    end

    it '404s in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      get :index

      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    it 'clears events and redirects to index' do
      PushNotification::LocalEventQueue.events << {
        url: 'test',
        payload: 'payload',
        jwt: 'jwt',
      }

      delete :destroy

      expect(PushNotification::LocalEventQueue.events.length).to eq(0)
      expect(response).to redirect_to(test_push_notification_url)
    end
  end
end
