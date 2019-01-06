require 'rails_helper'

RSpec.describe SignUp::EmailsController do
  describe '#show' do
    context 'email in session' do
      it 'renders the page and deletes the email from the session' do
        session[:email] = 'test@example.com'

        get :show

        expect(session[:email]).to be_nil
        expect(response).to render_template(:show)
      end
    end

    context 'no email in session' do
      it 'redirects to the new user registration path' do
        session[:email] = nil

        get :show

        expect(response).to redirect_to(sign_up_email_path)
      end
    end
  end
end
