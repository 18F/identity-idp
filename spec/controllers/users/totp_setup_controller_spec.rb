require 'rails_helper'

describe Users::TotpSetupController, devise: true do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
      )
    end
  end

  describe '#new' do
    context 'user is setting up authenticator app after account creation' do
      before do
        stub_analytics
        user = build(:user, :signed_up, :with_phone, with: { phone: '703-555-1212' })
        stub_sign_in(user)
        allow(@analytics).to receive(:track_event)
        get :new
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'sets new_totp_secret in user_session' do
        expect(subject.user_session[:new_totp_secret]).not_to be_nil
      end

      it 'can be used to generate a qrcode with UserDecorator#qrcode' do
        expect(
          subject.current_user.decorate.qrcode(subject.user_session[:new_totp_secret]),
        ).not_to be_nil
      end

      it 'captures an analytics event' do
        properties = { user_signed_up: true, totp_secret_present: true }

        expect(@analytics).
          to have_received(:track_event).with(Analytics::TOTP_SETUP_VISIT, properties)
      end
    end

    context 'user has already enabled authenticator app' do
      it 'redirects to profile page' do
        stub_sign_in

        allow(subject.current_user).to receive(:totp_enabled?).and_return(true)

        get :new

        expect(response).to redirect_to account_path
      end
    end

    context 'user is setting up authenticator app during account creation' do
      before do
        stub_analytics
        stub_sign_in_before_2fa
        allow(@analytics).to receive(:track_event)
        get :new
      end

      it 'returns a 200 status code' do
        expect(response.status).to eq(200)
      end

      it 'sets new_totp_secret in user_session' do
        expect(subject.user_session[:new_totp_secret]).not_to be_nil
      end

      it 'can be used to generate a qrcode with UserDecorator#qrcode' do
        expect(
          subject.current_user.decorate.qrcode(subject.user_session[:new_totp_secret]),
        ).not_to be_nil
      end

      it 'captures an analytics event' do
        properties = { user_signed_up: false, totp_secret_present: true }

        expect(@analytics).
          to have_received(:track_event).with(Analytics::TOTP_SETUP_VISIT, properties)
      end
    end
  end

  describe '#confirm' do
    context 'user is already signed up' do
      context 'when user presents invalid code' do
        before do
          user = build(:user, personal_key: 'ABCD-DEFG-HIJK-LMNO')
          stub_sign_in(user)
          stub_analytics
          allow(@analytics).to receive(:track_event)
          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.totp_enabled?).to be(false)

          result = {
            success: false,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::MULTI_FACTOR_AUTH_SETUP, result)
        end
      end

      context 'when user presents correct code' do
        before do
          user = build(:user, personal_key: 'ABCD-DEFG-HIJK-LMNO')
          secret = ROTP::Base32.random_base32
          stub_sign_in(user)
          stub_analytics
          allow(@analytics).to receive(:track_event)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { code: generate_totp_code(secret) }
        end

        it 'redirects to account_path with a success message' do
          expect(response).to redirect_to(account_path)
          expect(subject.user_session[:new_totp_secret]).to be_nil

          result = {
            success: true,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::MULTI_FACTOR_AUTH_SETUP, result)
        end
      end
    end

    context 'user is not yet signed up' do
      context 'when user presents invalid code' do
        before do
          stub_sign_in_before_2fa
          stub_analytics
          allow(@analytics).to receive(:track_event)
          subject.user_session[:new_totp_secret] = 'abcdehij'

          patch :confirm, params: { code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.totp_enabled?).to be(false)

          result = {
            success: false,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
          }
          expect(@analytics).to have_received(:track_event).
            with(Analytics::MULTI_FACTOR_AUTH_SETUP, result)
        end
      end

      context 'when user presents correct code' do
        before do
          secret = ROTP::Base32.random_base32
          stub_sign_in_before_2fa
          stub_analytics
          allow(@analytics).to receive(:track_event)
          subject.user_session[:new_totp_secret] = secret

          patch :confirm, params: { code: generate_totp_code(secret) }
        end

        it 'redirects to setup another factor without a flash message' do
          expect(response).to redirect_to(two_factor_options_success_url)
          redirect_to(two_factor_options_url)
          expect(flash[:success]).to be_nil
          expect(subject.user_session[:new_totp_secret]).to be_nil

          result = {
            success: true,
            errors: {},
            totp_secret_present: true,
            multi_factor_auth_method: 'totp',
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::MULTI_FACTOR_AUTH_SETUP, result)
        end
      end

      context 'when totp secret is no longer in user_session' do
        before do
          stub_sign_in_before_2fa
          stub_analytics
          allow(@analytics).to receive(:track_event)

          patch :confirm, params: { code: 123 }
        end

        it 'redirects with an error message' do
          expect(response).to redirect_to(authenticator_setup_path)
          expect(flash[:error]).to eq t('errors.invalid_totp')
          expect(subject.current_user.totp_enabled?).to be(false)

          result = {
            success: false,
            errors: {},
            totp_secret_present: false,
            multi_factor_auth_method: 'totp',
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::MULTI_FACTOR_AUTH_SETUP, result)
        end
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
        expect(response).to redirect_to(account_path)
        expect(flash[:success]).to eq t('notices.totp_disabled')
        expect(@analytics).to have_received(:track_event).with(Analytics::TOTP_USER_DISABLED)
        expect(subject).to have_received(:create_user_event).with(:authenticator_disabled)
      end
    end

    context 'when totp is the last mfa method' do
      it 'does not disable totp' do
        user = create(:user, :with_authentication_app)
        sign_in user

        delete :disable
        expect(user.reload.otp_secret_key).to_not be_nil
        expect(response).to redirect_to(account_path)
      end
    end
  end
end
