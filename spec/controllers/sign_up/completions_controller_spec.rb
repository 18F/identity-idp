require 'rails_helper'

describe SignUp::CompletionsController do
  describe '#show' do
    it 'tracks page visit' do
      stub_sign_in
      stub_analytics
      allow(@analytics).to receive(:track_event).with(Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT, { loa3: nil, service_provider_name: nil })

      get :show

      expect(@analytics).to have_received(:track_event).with(Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT, { loa3: nil, service_provider_name: nil })
    end
  end

  describe '#update' do
    it 'tracks analytics' do
      stub_sign_in
      stub_analytics
      session[:saml_request_url] = 'www.example.com'
      allow(@analytics).to receive(:track_event).with(Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE, { loa3: nil, service_provider_name: nil })

      patch :update

      expect(@analytics).to have_received(:track_event).with(Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE, { loa3: nil, service_provider_name: nil })
    end
  end
end
