require 'rails_helper'

describe MfaConfirmationController do
  describe 'GET /reauthn' do
    it 'presents the password confirmation form' do
      stub_sign_in

      get :new

      expect(response.status).to eq 200
    end
  end

  describe 'PUT /reauthn' do
    let(:user) { build(:user, password: 'password') }

    before do
      stub_sign_in(user)
    end

    context 'password is empty' do
      it 'redirects with error message' do
        post :create, user: { password: '' }

        expect(response).to redirect_to(user_password_confirm_path)
        expect(flash[:error]).to eq t('errors.confirm_password_incorrect')
      end
    end

    context 'password is wrong' do
      it 'redirects with error message' do
        post :create, user: { password: 'wrong' }

        expect(response).to redirect_to(user_password_confirm_path)
        expect(flash[:error]).to eq t('errors.confirm_password_incorrect')
      end
    end

    context 'password is correct' do
      it 'redirects to 2FA' do
        post :create, user: { password: 'password' }

        expect(response).to redirect_to(user_two_factor_authentication_path(reauthn: true))
      end
    end
  end
end
