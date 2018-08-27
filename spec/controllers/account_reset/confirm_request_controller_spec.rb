require 'rails_helper'

RSpec.describe AccountReset::ConfirmRequestController do
  describe '#show' do
    context 'no email in flash' do
      it 'redirects to the new user registration path' do
        get :show

        expect(response).to redirect_to(root_url)
      end
    end
  end
end
