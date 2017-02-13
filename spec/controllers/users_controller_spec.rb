require 'rails_helper'

describe UsersController do
  describe '#destroy' do
    it 'destroys the current user and redirects to sign in page, with a helpful flash message' do
      sign_in_as_user

      expect { delete :destroy }.to change(User, :count).by(-1)
      expect(response).to redirect_to(root_url)
      expect(flash.now[:success]).to eq t('loa1.cancel.success')
    end
  end
end
