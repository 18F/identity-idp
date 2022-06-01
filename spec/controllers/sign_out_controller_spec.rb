require 'rails_helper'

describe SignOutController do
  describe '#destroy' do
    it 'redirects to decorated_session.cancel_link_url with flash message' do
      stub_sign_in_before_2fa
      allow(controller.decorated_session).to receive(:cancel_link_url).and_return('foo')

      get :destroy

      expect(response).to redirect_to 'foo'
      expect(flash[:success]).to eq t('devise.sessions.signed_out')
    end

    it 'calls #sign_out and #delete_branded_experience' do
      expect(controller).to receive(:sign_out).and_call_original
      expect(controller).to receive(:delete_branded_experience)

      get :destroy
    end

    it 'tracks the event' do
      stub_sign_in_before_2fa
      stub_analytics
      allow(controller.decorated_session).to receive(:cancel_link_url).and_return('foo')

      expect(@analytics).
        to receive(:track_event).with('Logout Initiated', hash_including(method: 'cancel link'))

      get :destroy
    end
  end
end
