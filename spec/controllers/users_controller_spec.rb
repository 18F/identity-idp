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
  end
end
