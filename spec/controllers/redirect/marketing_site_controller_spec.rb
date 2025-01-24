require 'rails_helper'

RSpec.describe Redirect::MarketingSiteController do
  subject(:response) { get :show }

  before { stub_analytics }

  describe '#show' do
    it 'redirects to the marketing site' do
      expect(response).to redirect_to MarketingSite.base_url
    end

    it 'logs an event' do
      response
      expect(@analytics).to have_logged_event(
        'External Redirect',
        redirect_url: MarketingSite.base_url,
      )
    end
  end
end
