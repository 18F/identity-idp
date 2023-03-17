require 'rails_helper'

describe Redirect::ContactController do
  before do
    stub_analytics
  end

  describe '#show' do
    let(:location_params) { { flow: 'flow', step: 'step', location: 'location', foo: 'bar' } }
    it 'redirects to contact page' do
      redirect_url = IdentityConfig.store.idv_contact_url

      get :show, params: { **location_params }

      expect(response).to redirect_to redirect_url
      expect(@analytics).to have_logged_event(
        'Contact Page Redirect',
        flow: 'flow',
        location: 'location',
        redirect_url: redirect_url,
        step: 'step',
      )
    end
  end
end
