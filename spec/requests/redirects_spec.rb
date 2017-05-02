require 'rails_helper'

RSpec.describe 'Redirecting Legacy Routes', type: :request do
  describe '/profile' do
    it 'redirects to /account' do
      get '/profile'

      expect(response).to redirect_to('/account')
    end
  end

  describe '/profile/reactivate' do
    it 'redirects to /account/reactivate' do
      get '/profile/reactivate'

      expect(response).to redirect_to('/account/reactivate')
    end
  end

  describe '/profile/verify' do
    it 'redirects to /account/verify' do
      get '/profile/verify'

      expect(response).to redirect_to('/account/verify')
    end
  end
end
