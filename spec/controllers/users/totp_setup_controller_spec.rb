require 'rails_helper'

describe Users::TotpSetupController, devise: true do
  render_views

  describe 'before_actions' do
    it 'includes confirm_two_factor_authenticated' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#new' do
    before do
      sign_in_as_user
      get :new
    end

    it 'returns a 200 status code' do
      expect(response.status).to eq(200)
    end

    it 'sets new_totp_secret in user_session' do
      expect(subject.user_session[:new_totp_secret]).not_to be_nil
    end

    it 'can be used to generate a qrcode with UserDecorator#qrcode' do
      user_decorator = UserDecorator.new(subject.current_user)

      expect(user_decorator.qrcode(subject.user_session[:new_totp_secret])).not_to be_nil
    end

    it 'presents a QR code to the user' do
      expect(response.body).to include('QR Code for Authenticator App')
    end
  end

  describe '#confirm' do
    context 'when user presents invalid code' do
      before do
        sign_in_as_user
        get :new
        patch :confirm, code: 123
      end

      it 'redirects back to authenticator_setup_path' do
        expect(response).to redirect_to(authenticator_setup_path)
      end

      it 'sets flash[:error] message' do
        expect(flash[:error]).to eq t('errors.invalid_totp')
      end

      it 'does not enable TOTP for the current user' do
        expect(subject.current_user.totp_enabled?).to be(false)
      end
    end

    context 'when user presents correct code' do
      before do
        sign_in_as_user
        get :new
        expect(subject.current_user.totp_enabled?).to be(false)
        patch :confirm, code: generate_totp_code(subject.user_session[:new_totp_secret])
      end

      it 'redirects to edit_user_registration_path' do
        expect(response).to redirect_to(edit_user_registration_path)
      end

      it 'sets flash[:success] message' do
        expect(flash[:success]).to eq t('notices.totp_configured')
      end

      it 'enables TOTP for the current user' do
        expect(subject.current_user.totp_enabled?).to be(true)
      end

      it 'clears :new_totp_secret from session' do
        expect(subject.user_session[:new_totp_secret]).to be_nil
      end
    end
  end

  describe '#disable' do
    before do
      sign_in_as_user
    end

    context 'when a user has configured TOTP' do
      before do
        get :new
        patch :confirm, code: generate_totp_code(subject.user_session[:new_totp_secret])
        expect(subject.current_user.totp_enabled?).to be(true)
        delete :disable
      end

      it 'disables TOTP' do
        expect(subject.current_user.totp_enabled?).to be(false)
      end
    end
  end
end
