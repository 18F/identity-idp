require 'rails_helper'

describe 'IDV Outage', type: :request do
  before do
    allow(IdentityConfig.store).to receive(:idv_available).and_return(false)
  end
  describe '/verify' do
    it 'redirects to outage notice' do
      get '/verify'
      expect(response).to redirect_to('/verify/unavailable')
    end
  end
end
