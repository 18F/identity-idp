require 'rails_helper'

RSpec.describe Users::AuthorizationConfirmationController do
  let(:user) { create(:user, :fully_registered) }
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }
  let(:sp_request_url) { 'http://example.com/request/url' }
  let(:sp_request_id) { '123abc' }
  let(:sp_session) { { issuer: issuer, request_url: sp_request_url, request_id: sp_request_id } }

  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)
    stub_sign_in(user)
    controller.session[:sp] = sp_session
  end

  describe '#new' do
    it 'redirects for a user without an SP' do
      controller.session[:sp] = {}

      get :new

      expect(response).to redirect_to(account_url)
    end

    it 'renders for a signed in user' do
      get :new

      expect(response).to render_template(:new)
      expect(@analytics).to have_received(:track_event).with('Authentication Confirmation')
    end
  end

  describe '#create' do
    it 'redirects to the sp request url' do
      post :create

      expect(response).to redirect_to(sp_request_url)
      expect(@analytics).to have_received(:track_event).with(
        'Authentication Confirmation: Continue selected',
      )
    end
  end

  describe '#destroy' do
    it 'signs out the user and redircts to sign in with the request id' do
      expect(controller).to receive(:sign_out).with(:user)

      delete :destroy

      expect(response).to redirect_to(new_user_session_url(request_id: sp_request_id))
      expect(@analytics).to have_received(:track_event).with(
        'Authentication Confirmation: Reset selected',
      )
    end
  end
end
