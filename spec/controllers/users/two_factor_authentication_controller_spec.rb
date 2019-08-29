require 'rails_helper'

describe Users::TwoFactorAuthenticationController do
  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user,
        [:require_current_password, if: :current_password_required?],
        :check_already_authenticated,
        :reset_attempt_count_if_user_no_longer_locked_out,
        :apply_secure_headers_override,
      )
    end
  end

  describe '#check_already_authenticated' do
    controller do
      before_action :check_already_authenticated

      def index
        render plain: 'Hello'
      end
    end

    context 'when the user is fully authenticated and the context is authentication' do
      let(:user) { create(:user, :signed_up) }

      before do
        sign_in user
      end

      it 'redirects to the profile' do
        get :index

        expect(response).to redirect_to(account_url)
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

        expect(response).not_to redirect_to(account_url)
        expect(response.code).to eq('200')
      end
    end
  end

  describe '#show' do
    context 'when user is piv/cac enabled' do
      it 'renders the piv/cac entry screen' do
        user = build(:user)
        stub_sign_in_before_2fa(user)
        allow_any_instance_of(
          TwoFactorAuthentication::PivCacPolicy,
        ).to receive(:enabled?).and_return(true)

        get :show

        expect(response).to redirect_to login_two_factor_piv_cac_path
      end
    end

    context 'when user is TOTP enabled' do
      it 'renders the :confirm_totp view' do
        user = build(:user)
        stub_sign_in_before_2fa(user)
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(true)

        get :show

        expect(response).to redirect_to login_two_factor_authenticator_path
      end
    end

    context 'when user is webauthn enabled' do
      it 'renders the :webauthn view' do
        stub_sign_in_before_2fa(build(:user, :with_webauthn))

        allow_any_instance_of(
          TwoFactorAuthentication::WebauthnPolicy,
        ).to receive(:enabled?).and_return(true)

        get :show

        expect(response).to redirect_to login_two_factor_webauthn_path
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when the user has already set up 2FA' do
      it 'sends OTP via otp_delivery_preference and prompts for OTP' do
        stub_sign_in_before_2fa(create(:user, :with_phone, with: { phone: '+1 (703) 555-1212' }))

        get :show

        expect(response).
          to redirect_to login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
      end
    end

    context 'when the user has not already set up 2FA' do
      it 'redirects to set up 2FA' do
        stub_sign_in_before_2fa(build(:user))
        get :show

        expect(response).to redirect_to two_factor_options_url
      end
    end
  end

  describe '#send_code' do
    context 'when selecting SMS OTP delivery' do
      before do
        @user = create(:user, :with_phone)
        sign_in_before_2fa(@user)
        @old_otp = subject.current_user.direct_otp
        allow(Telephony).to receive(:send_authentication_otp)
      end

      it 'sends OTP via SMS for sign in' do
        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }

        expect(Telephony).to have_received(:send_authentication_otp).with(
          otp: subject.current_user.direct_otp,
          to: MfaContext.new(subject.current_user).phone_configurations.first.phone,
          expiration: 10,
          channel: :sms,
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false),
        )
      end

      it 'tracks the events' do
        stub_analytics

        analytics_hash = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
          resend: nil,
          context: 'authentication',
          country_code: 'US',
          area_code: '202',
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::OTP_DELIVERY_SELECTION, analytics_hash)

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
      end

      it 'calls OtpRateLimiter#exceeded_otp_send_limit? and #increment' do
        otp_rate_limiter = instance_double(OtpRateLimiter)
        allow(OtpRateLimiter).to receive(:new).with(
          phone: MfaContext.new(@user).phone_configurations.first.phone,
          user: @user,
        ).and_return(otp_rate_limiter)

        expect(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).twice
        expect(otp_rate_limiter).to receive(:increment)

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
      end

      it 'marks the user as locked out after too many attempts' do
        expect(@user.second_factor_locked_at).to be_nil

        (Figaro.env.otp_delivery_blocklist_maxretry.to_i + 1).times do
          get :send_code, params: {
            otp_delivery_selection_form: { otp_delivery_preference: 'sms',
                                           otp_make_default_number: nil },
          }
        end

        expect(@user.reload.second_factor_locked_at.to_f).to be_within(0.1).of(Time.zone.now.to_f)
      end
    end

    context 'when selecting voice OTP delivery' do
      before do
        user = create(:user, :signed_up, otp_delivery_preference: 'voice')
        sign_in_before_2fa(user)
        @old_otp = subject.current_user.direct_otp
        allow(Telephony).to receive(:send_authentication_otp)
      end

      it 'sends OTP via voice' do
        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'voice' },
        }

        expect(Telephony).to have_received(:send_authentication_otp).with(
          otp: subject.current_user.direct_otp,
          to: MfaContext.new(subject.current_user).phone_configurations.first.phone,
          expiration: 10,
          channel: :voice,
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(otp_delivery_preference: 'voice', reauthn: false),
        )
      end

      it 'tracks the event' do
        stub_analytics

        analytics_hash = {
          success: true,
          errors: {},
          otp_delivery_preference: 'voice',
          resend: nil,
          context: 'authentication',
          country_code: 'US',
          area_code: '202',
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::OTP_DELIVERY_SELECTION, analytics_hash)

        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'voice',
                                         otp_make_default_number: nil },
        }
      end
    end

    context 'phone is not confirmed' do
      before do
        @user = create(:user)
        @unconfirmed_phone = '+1 (202) 555-1213'

        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        subject.user_session[:unconfirmed_phone] = @unconfirmed_phone
      end

      it 'sends OTP inline when confirming phone' do
        allow(Telephony).to receive(:send_confirmation_otp)

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }

        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: subject.current_user.direct_otp,
          to: @unconfirmed_phone,
          expiration: 10,
          channel: :sms,
        )
      end

      it 'flashes an sms error when the telephony gem responds with an sms error' do
        telephony_error = Telephony::TelephonyError.new('error message')

        allow(Telephony).to receive(:send_confirmation_otp).and_raise(telephony_error)

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }

        expect(flash[:error]).to eq(telephony_error.friendly_message)
      end
    end

    context 'when selecting an invalid delivery method' do
      before do
        sign_in_before_2fa
      end

      it 'redirects user to choose a valid delivery method' do
        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'pigeon' },
        }

        expect(response).to redirect_to login_two_factor_url(otp_delivery_preference: 'sms')
      end
    end
  end
end
