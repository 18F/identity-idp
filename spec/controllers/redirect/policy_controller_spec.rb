require 'rails_helper'

RSpec.describe Redirect::PolicyController do
  before do
    stub_analytics
  end

  describe '#show' do
    let(:location_params) { { flow: 'flow', step: 'step', location: 'location', foo: 'bar' } }
    it 'redirects to policy page' do
      redirect_url = MarketingSite.security_and_privacy_practices_url

      get :show, params: location_params

      expect(response).to redirect_to redirect_url
      expect(@analytics).to have_logged_event(
        'Policy Page Redirect',
        flow: 'flow',
        location: 'location',
        redirect_url:,
        step: 'step',
      )
    end
  end
end
