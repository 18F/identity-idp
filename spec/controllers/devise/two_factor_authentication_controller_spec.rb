require 'rails_helper'

describe Devise::TwoFactorAuthenticationController, devise: true do
  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
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

  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        stub_sign_in_before_2fa(User.new(phone: '+1 (703) 555-1212'))
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
  end

  describe '#send_code' do
    context 'when selecting SMS OTP delivery' do
      before do
        sign_in_before_2fa
        @old_otp = subject.current_user.direct_otp
        allow(SmsSenderOtpJob).to receive(:perform_later)
      end

      it 'sends OTP via SMS' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }

        expect(SmsSenderOtpJob).to have_received(:perform_later).
          with(subject.current_user.direct_otp, subject.current_user.phone)
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to login_two_factor_path(delivery_method: 'sms')
      end

      it 'tracks the events' do
        stub_analytics

        analytics_hash = { success?: true, delivery_method: 'sms', resend?: nil, errors: [] }

        expect(@analytics).to receive(:track_event).
          with(:otp_delivery_selection, analytics_hash)
        expect(@analytics).to receive(:track_event).with('GET request for ' \
          'two_factor_authentication#send_code')

        get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }
      end

      it 'notifies the user of OTP transmission' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'sms' }

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
        get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }

        expect(VoiceSenderOtpJob).to have_received(:perform_later).
          with(subject.current_user.direct_otp, subject.current_user.phone)
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to login_two_factor_path(delivery_method: 'voice')
      end

      it 'tracks the event' do
        stub_analytics

        analytics_hash = { success?: true, delivery_method: 'voice', resend?: nil, errors: [] }

        expect(@analytics).to receive(:track_event).
          with(:otp_delivery_selection, analytics_hash)
        expect(@analytics).to receive(:track_event).with('GET request for ' \
          'two_factor_authentication#send_code')

        get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }
      end

      it 'notifies the user of OTP transmission' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'voice' }

        expect(flash[:success]).to eq t('notices.send_code.voice')
      end
    end

    context 'when selecting an invalid delivery method' do
      before do
        sign_in_before_2fa
      end

      it 'redirects user to choose a valid delivery method' do
        get :send_code, otp_delivery_selection_form: { otp_method: 'pigeon' }

        expect(response).to redirect_to user_two_factor_authentication_path
      end
    end
  end
end
