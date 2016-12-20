require 'rails_helper'

describe Users::TwoFactorAuthenticationController do
  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user,
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

    context 'when the user is fully authenticated and the context is authentication' do
      let(:user) { create(:user, :signed_up) }

      before do
        sign_in user
      end

      it 'redirects to the profile' do
        get :index

        expect(response).to redirect_to(profile_url)
      end
    end

    context 'when the user is fully authenticated and the context is not authentication' do
      let(:user) { create(:user, :signed_up) }

      before do
        sign_in user
        subject.user_session[:context] = 'confirmation'
      end

      it 'does not redirect to the profile' do
        get :index

        expect(response).to_not be_redirect
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

  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        stub_sign_in_before_2fa(build(:user, phone: '+1 (703) 555-1212'))
      end

      it 'renders the :show view' do
        get :show

        expect(response).to_not be_redirect
        expect(response).to render_template(:show)
      end

      context 'when user is TOTP enabled' do
        before do
          allow(subject.current_user).to receive(:totp_enabled?).and_return(true)
        end

        it 'renders the :confirm_totp view' do
          get :show

          expect(response).to redirect_to login_two_factor_authenticator_path
        end
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe '#send_code' do
    context 'when selecting SMS OTP delivery' do
      before do
        sign_in_before_2fa
        @old_otp = subject.current_user.direct_otp
        allow(SmsOtpSenderJob).to receive(:perform_later)
      end

      it 'sends OTP via SMS' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }

        expect(SmsOtpSenderJob).to have_received(:perform_later).with(
          code: subject.current_user.direct_otp,
          phone: subject.current_user.phone,
          otp_created_at: subject.current_user.direct_otp_sent_at.to_s
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(delivery_method: 'sms', reauthn: false)
        )
      end

      it 'tracks the events' do
        stub_analytics

        analytics_hash = {
          success: true,
          delivery_method: 'sms',
          resend: nil,
          errors: [],
          context: 'authentication'
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::OTP_DELIVERY_SELECTION, analytics_hash)

        get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }
      end

      context 'first request' do
        it 'does not notify the user of OTP transmission via flash message' do
          get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }

          expect(flash[:success]).to eq nil
        end
      end

      context 'multiple requests' do
        it 'notifies the user of OTP transmission via flash message' do
          get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }
          get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }

          expect(flash[:success]).to eq t('notices.send_code.sms')
        end
      end
    end

    context 'when selecting voice OTP delivery' do
      before do
        sign_in_before_2fa
        @old_otp = subject.current_user.direct_otp
        allow(VoiceOtpSenderJob).to receive(:perform_later)
      end

      it 'sends OTP via voice' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }

        expect(VoiceOtpSenderJob).to have_received(:perform_later).with(
          code: subject.current_user.direct_otp,
          phone: subject.current_user.phone,
          otp_created_at: subject.current_user.direct_otp_sent_at.to_s
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(delivery_method: 'voice', reauthn: false)
        )
      end

      it 'tracks the event' do
        stub_analytics

        analytics_hash = {
          success: true,
          delivery_method: 'voice',
          resend: nil,
          errors: [],
          context: 'authentication'
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::OTP_DELIVERY_SELECTION, analytics_hash)

        get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }
      end

      context 'first request' do
        it 'does not notify the user of OTP transmission via flash message' do
          get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }

          expect(flash[:success]).to eq nil
        end
      end

      context 'multiple requests' do
        it 'notifies the user of OTP transmission via flash message' do
          get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }
          get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }

          expect(flash[:success]).to eq t('notices.send_code.voice')
        end
      end
    end

    context 'when selecting an invalid delivery method' do
      before do
        sign_in_before_2fa
      end

      it 'redirects user to choose a valid delivery method' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'pigeon' }

        expect(response).to redirect_to user_two_factor_authentication_path(reauthn: false)
      end
    end
  end
end
