require 'rails_helper'

RSpec.describe AccountReset::ConfirmDeleteAccountController do
  describe '#show' do
    context 'email in session' do
      it 'renders the page and deletes the email from the session' do
        allow(controller).to receive(:flash).and_return(email: 'test@example.com')

        get :show

        expect(response).to render_template(:show)
      end
    end

    context 'no email in session' do
      it 'redirects to the new user registration path' do
        get :show

        expect(response).to redirect_to(root_url)
      end
    end
  end
end
