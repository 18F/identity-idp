require 'rails_helper'

RSpec.describe AccountReset::ConfirmRequestController do
  describe '#show' do
    context 'no email in flash' do
      it 'redirects to the new user registration path' do
        get :show

        expect(response).to redirect_to(root_url)
      end
    end

    context 'email is present in flash' do
      it 'renders the show template' do
        allow(controller).to receive(:flash).and_return(email: 'test@test.com')
        get :show

        expect(response).to render_template(:show)
      end
    end
  end
end
