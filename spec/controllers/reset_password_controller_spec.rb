require 'rails_helper'

describe ResetPasswordController do
  describe '#index' do
    it 'renders the page' do
      get :index

      expect(response).to render_template(:index)
    end
  end

  describe '#update' do
    context 'with personal_key: true' do
      it 'redirects to new password page, sets session flag to true, and shows a flash message' do
        put :update, personal_key: 'true'
        expect(session[:personal_key]).to eq true
        expect(flash[:notice]).to eq t('notices.password_reset')
        expect(response).to redirect_to(new_user_password_url)
      end
    end

    context 'with personal_key: false' do
      it 'redirects and sets session key to false' do
        put :update, personal_key: 'false'
        expect(session[:personal_key]).to eq false
        expect(flash[:notice]).to be_nil
        expect(response).to redirect_to(new_user_password_url)
      end
    end
  end
end
