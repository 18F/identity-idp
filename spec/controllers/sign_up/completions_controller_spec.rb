require 'rails_helper'

describe SignUp::CompletionsController do
  describe '#show' do
    it 'tracks page visit' do
      stub_sign_in
      subject.session[:sp] = {}
      stub_analytics
      allow(@analytics).to receive(:track_event)

      get :show

      expect(@analytics).to have_received(:track_event).with(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
        { loa3: nil, service_provider_name: nil }
      )
    end

    it 'requires user to be logged in' do
      subject.session[:sp] = {}
      get :show

      expect(response).to redirect_to(new_user_session_url)
    end

    it 'requires service provider info in session' do
      stub_sign_in
      subject.session[:sp] = nil

      get :show

      expect(response).to redirect_to(new_user_session_url)
    end
  end

  describe '#update' do
    it 'tracks analytics' do
      stub_sign_in
      stub_analytics
      session[:saml_request_url] = 'www.example.com'
      allow(@analytics).to receive(:track_event)

      patch :update

      expect(@analytics).to have_received(:track_event).with(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE,
        { loa3: nil, service_provider_name: nil }
      )
    end
  end
end
