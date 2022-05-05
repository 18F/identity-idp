require 'rails_helper'

describe MfaConfirmationController do
  describe '#show' do
    it 'presents the mfa confirmation page.' do
      stub_sign_in

      get :show, params: { final_path: account_url }

      expect(response.status).to eq 200
    end
  end

  describe '#new' do
    it 'presents the password confirmation form' do
      stub_sign_in

      get :new

      expect(response.status).to eq 200
      expect(session[:password_attempts]).to eq 0
    end

    it 'does not reset password attempts if already set' do
      stub_sign_in
      session[:password_attempts] = 1

      get :new

      expect(session[:password_attempts]).to eq 1
    end
  end

  describe '#create' do
    let(:user) { build(:user, password: 'password') }

    before do
      stub_sign_in(user)
      session[:password_attempts] = 1
    end

    context 'password is empty' do
      it 'redirects with error message and increments password attempts' do
        post :create, params: { user: { password: '' } }

        expect(response).to redirect_to(user_password_confirm_path)
        expect(flash[:error]).to eq t('errors.confirm_password_incorrect')
        expect(session[:password_attempts]).to eq 2
      end
    end

    context 'password is wrong' do
      it 'redirects with error message and increments password attempts' do
        post :create, params: { user: { password: 'wrong' } }

        expect(response).to redirect_to(user_password_confirm_path)
        expect(flash[:error]).to eq t('errors.confirm_password_incorrect')
        expect(session[:password_attempts]).to eq 2
      end

      context 'session data is missing' do
        before do
          session.delete(:password_attempts)
        end

        it 'redirects and increments the password count' do
          post :create, params: { user: { password: 'wrong' } }

          expect(response).to redirect_to(user_password_confirm_path)
          expect(session[:password_attempts]).to eq 1
        end
      end
    end

    context 'password is correct' do
      it 'redirects to 2FA and resets password attempts' do
        post :create, params: { user: { password: 'password' } }

        expect(response).to redirect_to(user_two_factor_authentication_path(reauthn: true))
        expect(session[:password_attempts]).to eq 0
      end
    end
  end

  describe 'password attempts counter' do
    context 'max password attempts reached' do
      it 'signs the user out' do
        user = create(:user, :signed_up)
        sign_in user
        session[:password_attempts] = 0
        stub_analytics
        allow(@analytics).to receive(:track_event)

        max_allowed_attempts = IdentityConfig.store.password_max_attempts
        max_allowed_attempts.times do
          post :create, params: { user: { password: 'wrong' } }
        end

        expect(response).to redirect_to(root_path)
        expect(controller.current_user).to be_nil
        expect(flash[:error]).to eq t('errors.max_password_attempts_reached')
        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_MAX_ATTEMPTS)
      end
    end

    context 'last password attempt is correct' do
      it 'does not sign the user out' do
        user = build_stubbed(:user, password: 'password')
        stub_sign_in user
        session[:password_attempts] = 0

        max_allowed_attempts = IdentityConfig.store.password_max_attempts
        (max_allowed_attempts - 1).times do
          post :create, params: { user: { password: 'wrong' } }
        end

        post :create, params: { user: { password: 'password' } }

        expect(response).to redirect_to user_two_factor_authentication_path(reauthn: true)
      end
    end
  end
end
