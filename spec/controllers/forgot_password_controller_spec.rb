require 'rails_helper'

RSpec.describe ForgotPasswordController do
  describe '#show' do
    context 'email in session' do
      it 'renders the page' do
        session[:email] = 'test@example.com'

        get :show

        expect(response).to render_template(:show)
      end
    end

    context 'no email in session' do
      it 'redirects to the new user password path' do
        session[:email] = nil

        get :show

        expect(response).to redirect_to(new_user_password_path)
      end
    end
  end
end
