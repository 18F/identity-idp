require 'rails_helper'

describe UsersController do
  describe '#destroy' do
    it 'redirects and displays the flash message if no user is present' do
      delete :destroy

      expect(response).to redirect_to(root_url)
      expect(flash.now[:success]).to eq t('sign_up.cancel.success')
    end

    it 'destroys the current user and redirects to sign in page, with a helpful flash message' do
      sign_in_as_user

      expect { delete :destroy }.to change(User, :count).by(-1)
      expect(response).to redirect_to(root_url)
      expect(flash.now[:success]).to eq t('sign_up.cancel.success')
    end

    it 'finds the proper user and removes their record without `current_user`' do
      confirmation_token = '1'

      create(:user, confirmation_token: confirmation_token)
      subject.session[:user_confirmation_token] = confirmation_token

      expect { delete :destroy }.to change(User, :count).by(-1)
    end

    it 'redirects to the branded start page if the user came from an SP' do
      session[:sp] = { issuer: 'http://localhost:3000', request_id: 'foo' }

      delete :destroy

      expect(response).
        to redirect_to sign_up_start_path(request_id: 'foo')
    end
  end
end
