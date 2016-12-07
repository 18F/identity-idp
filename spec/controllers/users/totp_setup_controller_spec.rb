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
      user_decorator = subject.current_user.decorate

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

        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :new
        patch :confirm, code: 123
      end

      it 'redirects with an error message' do
        expect(response).to redirect_to(authenticator_setup_path)
        expect(flash[:error]).to eq t('errors.invalid_totp')
        expect(subject.current_user.totp_enabled?).to be(false)

        result = {
          success: false
        }
        expect(@analytics).to have_received(:track_event).with(Analytics::TOTP_SETUP, result)
      end
    end

    context 'when user presents correct code' do
      before do
        sign_in_as_user

        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :new
        allow(subject).to receive(:create_user_event)
        patch :confirm, code: generate_totp_code(subject.user_session[:new_totp_secret])
      end

      it 'redirects to profile_path with a success message' do
        expect(response).to redirect_to(profile_path)
        expect(flash[:success]).to eq t('notices.totp_configured')
        expect(subject.current_user.totp_enabled?).to be(true)
        expect(subject.user_session[:new_totp_secret]).to be_nil

        result = {
          success: true
        }
        expect(@analytics).to have_received(:track_event).with(Analytics::TOTP_SETUP, result)
      end

      it 'creates an :authenticator_enabled event' do
        expect(subject).to have_received(:create_user_event).with(:authenticator_enabled)
      end
    end
  end

  describe '#disable' do
    context 'when a user has configured TOTP' do
      it 'disables TOTP' do
        user = create(:user, :signed_up, otp_secret_key: 'foo')
        sign_in user

        stub_analytics
        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        delete :disable

        expect(user.reload.otp_secret_key).to be_nil
        expect(user.reload.totp_enabled?).to be(false)
        expect(response).to redirect_to(profile_path)
        expect(flash[:success]).to eq t('notices.totp_disabled')
        expect(@analytics).to have_received(:track_event).with(Analytics::TOTP_USER_DISABLED)
        expect(subject).to have_received(:create_user_event).with(:authenticator_disabled)
      end
    end
  end
end
