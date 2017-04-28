require 'rails_helper'

RSpec.describe 'Redirecting Legacy Routes', type: :request do
  describe '/profile' do
    it 'redirects to /account' do
      get '/profile'

      expect(response).to redirect_to('/account')
    end
  end
end
