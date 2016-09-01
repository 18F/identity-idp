require 'rails_helper'

describe Devise::TwoFactorAuthenticationController, devise: true do
  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_scope!,
        :verify_user_is_not_second_factor_locked,
        :handle_two_factor_authentication,
        :check_already_authenticated
      )
    end
  end

  describe '#check_already_authenticated' do
    controller do
      before_action :check_already_authenticated

      def index
        render text: 'Hello'
      end
    end

    context 'when the user is fully authenticated' do
      let(:user) { create(:user, :signed_up) }

      before do
        sign_in user
      end

      it 'redirects to the profile' do
        get :index

        expect(response).to redirect_to(profile_url)
      end
    end

    context 'when the user is not fully signed in' do
      before do
        sign_in_before_2fa
      end

      it 'does not redirect to the profile' do
        get :index

        expect(response).not_to redirect_to(profile_url)
        expect(response.code).to eq('200')
      end
    end
  end

  describe '#update' do
    context 'when the user enters an invalid OTP' do
      before do
        sign_in_before_2fa

        stub_analytics
        expect(@analytics).to receive(:track_event).with('User entered invalid 2FA code')

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        expect(subject.current_user).to receive(:authenticate_otp).and_return(false)
        patch :update, code: '12345', delivery_method: :sms
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the OTP entry screen' do
        expect(response).to redirect_to(otp_confirm_path(delivery_method: :sms))
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('devise.two_factor_authentication.attempt_failed')
      end
    end

    context 'when the user has reached the max number of OTP attempts' do
      it 'tracks the event' do
        sign_in_before_2fa

        stub_analytics

        expect(@analytics).to receive(:track_event).exactly(3).times.
          with('User entered invalid 2FA code')
        expect(@analytics).to receive(:track_event).with('User reached max 2FA attempts')

        3.times { patch :update, code: '12345' }
      end
    end

    context 'when the user enters a valid OTP' do
      before do
        sign_in_before_2fa
        expect(subject.current_user).to receive(:authenticate_otp).and_return(true)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'redirects to the profile' do
        patch :update, code: subject.current_user.reload.direct_otp

        expect(response).to redirect_to profile_path
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update(second_factor_attempts_count: 1)
        patch :update, code: subject.current_user.reload.direct_otp

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('User 2FA successful')
        expect(@analytics).to receive(:track_event).with('Authentication Successful')

        patch :update, code: subject.current_user.reload.direct_otp
      end
    end

    context 'when user has not changed their number' do
      it 'does not perform SmsSenderNumberChangeJob' do
        user = create(:user, :signed_up)
        sign_in user

        expect(SmsSenderNumberChangeJob).to_not receive(:perform_later).with(user)

        patch :update, code: user.direct_otp
      end
    end

    context 'when the user is TOTP enabled' do
      before do
        sign_in_before_2fa
        @secret = subject.current_user.generate_totp_secret
        subject.current_user.otp_secret_key = @secret
      end

      context 'when the user enters a valid TOTP' do
        before do
          patch :update, code: generate_totp_code(@secret)
        end

        it 'redirects to the profile' do
          expect(response).to redirect_to profile_path
        end
      end

      context 'when the user enters an invalid TOTP' do
        before do
          patch :update, code: 'abc', delivery_method: :totp
        end

        it 'increments second_factor_attempts_count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 're-renders the TOTP entry screen' do
          expect(response).to render_template(:confirm_totp)
        end

        it 'displays flash error message' do
          expect(flash[:error]).to eq t('devise.two_factor_authentication.attempt_failed')
        end
      end

      context 'user requests a direct OTP via SMS' do
        before do
          get :new, delivery_method: :sms
        end

        it 'redirects to the confirmation screen' do
          expect(response).to_not render_template(:confirm_totp)
          expect(response).to redirect_to(otp_confirm_path(delivery_method: :sms))
        end

        context 'when user enters correct OTP' do
          it 'redirects to the profile' do
            patch :update, code: subject.current_user.direct_otp
            expect(response).to redirect_to profile_path
          end
        end

        context 'when user enters incorrect OTP' do
          it 'redirects to the confirmation screen' do
            patch :update, code: 'rrrr', delivery_method: :sms
            expect(flash[:error]).to eq t('devise.two_factor_authentication.attempt_failed')
            expect(response).to redirect_to(otp_confirm_path(delivery_method: :sms))
          end
        end
      end

      context 'user requests a direct OTP via voice' do
        before do
          get :new, delivery_method: :voice
        end

        context 'when user enters correct OTP' do
          it 'redirects to the profile' do
            patch :update, code: subject.current_user.direct_otp
            expect(response).to redirect_to profile_path
          end
        end

        context 'when user enters incorrect OTP' do
          it 'redirects to the confirmation screen' do
            patch :update, code: 'rrrr', delivery_method: :voice
            expect(flash[:error]).to eq t('devise.two_factor_authentication.attempt_failed')
            expect(response).to redirect_to(otp_confirm_path(delivery_method: :voice))
          end
        end
      end
    end

    context 'when the user lockout period expires' do
      before do
        sign_in_before_2fa
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - Devise.direct_otp_valid_for - 1.second,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits an invalid OTP' do
        before do
          patch :update, code: '12345'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a valid OTP' do
        before do
          patch :update, code: subject.current_user.direct_otp
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end
  end

  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        sign_in_before_2fa
      end

      it 'renders the :show view' do
        get :show
        expect(response).to_not be_redirect
      end

      context 'when user is TOTP enabled' do
        before do
          allow(subject.current_user).to receive(:totp_enabled?).and_return(true)
        end

        it 'renders the :confirm_totp view' do
          get :show
          expect(response).to_not be_redirect
          expect(response).to render_template(:confirm_totp)
        end
      end
    end
  end

  describe '#confirm' do
    context 'when resource is not fully authenticated yet' do
      before do
        sign_in_before_2fa
      end

      context 'when FeatureManagement.prefill_otp_codes? is true' do
        it 'sets @code_value to correct OTP value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
          get :confirm

          expect(assigns(:code_value)).to eq(subject.current_user.direct_otp)
        end
      end

      context 'when FeatureManagement.prefill_otp_codes? is false' do
        it 'does not set @code_value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(false)
          get :confirm

          expect(assigns(:code_value)).to be_nil
        end
      end
    end
  end

  describe '#new' do
    before do
      sign_in_before_2fa
    end

    it 'redirects to :show' do
      get :new, delivery_method: :sms

      expect(response).to redirect_to(action: :confirm, delivery_method: :sms)
    end

    it 'sends a new OTP' do
      old_otp = subject.current_user.direct_otp
      allow(SmsSenderOtpJob).to receive(:perform_later)
      get :new

      expect(SmsSenderOtpJob).to have_received(:perform_later).
        with(subject.current_user.direct_otp, subject.current_user.phone)
      expect(subject.current_user.direct_otp).not_to eq(old_otp)
      expect(subject.current_user.direct_otp).not_to be_nil
    end

    it 'tracks the event' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with('GET request for two_factor_authentication#new')
      expect(@analytics).to receive(:track_event).with('User requested a new OTP code')

      get :new
    end

    context 'when selecting an unsupported delivery method' do
      before do
        allow(SmsSenderOtpJob).to receive(:perform_later)
        get :new, delivery_method: :email
      end

      it 'sends OTP via SMS' do
        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(subject.current_user.direct_otp, subject.current_user.phone)
      end
    end
  end

  describe '#send_code' do
    context 'when selecting SMS OTP delivery' do
      before do
        sign_in_before_2fa
        @old_otp = subject.current_user.direct_otp
        allow(SmsSenderOtpJob).to receive(:perform_later)
      end

      it 'sends OTP via SMS' do
        get :send_code, delivery_method: :sms

        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(subject.current_user.direct_otp, subject.current_user.phone)
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
      end

      it 'tracks the events' do
        stub_analytics

        expect(@analytics).to receive(:track_event).with('User requested sms OTP delivery')
        expect(@analytics).to receive(:track_event).with('GET request for ' \
          'two_factor_authentication#send_code')

        get :send_code, delivery_method: :sms
      end

      it 'notifies the user of OTP transmission' do
        get :send_code, delivery_method: :sms

        expect(flash[:success]).to eq t('notices.send_code.sms')
      end
    end

    context 'when selecting voice OTP delivery' do
      before do
        sign_in_before_2fa
        @old_otp = subject.current_user.direct_otp
        allow(VoiceSenderOtpJob).to receive(:perform_later)
      end

      it 'sends OTP via voice' do
        get :send_code, delivery_method: :voice

        expect(VoiceSenderOtpJob).to have_received(:perform_later).
          with(subject.current_user.direct_otp, subject.current_user.phone)
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
      end

      it 'tracks the event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('User requested voice OTP delivery')
        expect(@analytics).to receive(:track_event).with('GET request for ' \
          'two_factor_authentication#send_code')

        get :send_code, delivery_method: :voice
      end

      it 'notifies the user of OTP transmission' do
        get :send_code, delivery_method: :voice

        expect(flash[:success]).to eq t('notices.send_code.voice')
      end
    end

    context 'when selecting an unsupported delivery method' do
      before do
        sign_in_before_2fa
        @old_otp = subject.current_user.direct_otp
        allow(SmsSenderOtpJob).to receive(:perform_later)
      end

      it 'sends OTP via SMS' do
        get :send_code, delivery_method: :pigeon

        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(subject.current_user.direct_otp, subject.current_user.phone)
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
      end
    end
  end
end
