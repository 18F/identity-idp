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

  describe '/account/verify' do
    it 'redirects to /verify/by_mail' do
      get '/account/verify'

      expect(response).to redirect_to('/verify/by_mail')
    end
  end

  describe '/account/verify/confirm_start_over' do
    it 'redirects to /verify/by_mail/confirm_start_over' do
      get '/account/verify/confirm_start_over'

      expect(response).to redirect_to('/verify/by_mail/confirm_start_over')
    end
  end
end
