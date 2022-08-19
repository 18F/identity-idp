require 'rails_helper'

describe Users::TwoFactorAuthenticationController do
  include ActionView::Helpers::DateHelper

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
        allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
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
      before do
        user = build(:user)
        stub_sign_in_before_2fa(user)
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(true)
      end

      it 'renders the :confirm_totp view' do
        get :show

        expect(response).to redirect_to login_two_factor_authenticator_path
      end

      it 'passes reauthn parameter on redirect' do
        get :show, params: { reauthn: 'true' }

        expect(response).to redirect_to login_two_factor_authenticator_path(reauthn: 'true')
      end
    end

    context 'when user is authenticated with a remembered device via phone' do
      it 'does redirect to the profile' do
        user = create(:user, :with_phone, with: { phone: '+1 (703) 555-1212' })
        stub_sign_in_before_2fa(user)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: Time.zone.now).to_json,
          expires: 2.days.from_now,
        }

        get :show

        expect(Telephony::Test::Message.messages.length).to eq(0)
        expect(Telephony::Test::Call.calls.length).to eq(0)
        expect(response).to redirect_to(account_path)
      end

      it 'does redirect to sms if reauthn parameter is true' do
        user = create(:user, :with_phone, with: { phone: '+1 (703) 555-1212' })
        stub_sign_in_before_2fa(user)

        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: Time.zone.now).to_json,
          expires: 2.days.from_now,
        }

        get :show, params: { reauthn: 'true' }

        expect(Telephony::Test::Message.messages.length).to eq(1)
        expect(Telephony::Test::Call.calls.length).to eq(0)
        expect(response).to redirect_to(
          login_two_factor_path(otp_delivery_preference: 'sms', reauthn: 'true'),
        )
      end
    end

    context 'when user has backup codes' do
      before do
        user = build(:user)
        stub_sign_in_before_2fa(user)

        allow_any_instance_of(
          TwoFactorAuthentication::BackupCodePolicy,
        ).to receive(:configured?).and_return(true)
      end

      it 'renders the :backup_code view' do
        get :show

        expect(response).to redirect_to login_two_factor_backup_code_url
      end

      it 'passes reauthn parameter on redirect' do
        get :show, params: { reauthn: 'true' }

        expect(response).to redirect_to login_two_factor_backup_code_url(reauthn: 'true')
      end
    end

    context 'when user is webauthn enabled' do
      before do
        stub_sign_in_before_2fa(create(:user, :with_webauthn))
      end

      it 'renders the :webauthn view' do
        get :show

        expect(response).to redirect_to login_two_factor_webauthn_path(platform: false)
      end

      it 'passes reauthn parameter on redirect' do
        get :show, params: { reauthn: 'true' }

        expect(response).to redirect_to login_two_factor_webauthn_path(
          reauthn: 'true',
          platform: false,
        )
      end

      it 'passes the platform parameter if the user has a platform autheticator' do
        controller.current_user.webauthn_configurations.first.update!(platform_authenticator: true)

        get :show

        expect(response).to redirect_to login_two_factor_webauthn_path(platform: true)
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

        expect(Telephony::Test::Message.messages.length).to eq(1)
        expect(Telephony::Test::Call.calls.length).to eq(0)
        expect(response).
          to redirect_to login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
      end

      context 'when no options are enabled and available for use' do
        before do
          allow_any_instance_of(VendorStatus).to receive(:any_phone_vendor_outage?).and_return(true)
        end

        it 'redirects to mfa options page' do
          stub_sign_in_before_2fa(create(:user, :with_phone, with: { phone: '+1 (703) 555-1212' }))

          get :show

          expect(response).to redirect_to login_two_factor_options_path
        end
      end
    end

    context 'when the user has not already set up 2FA' do
      it 'redirects to set up 2FA' do
        stub_sign_in_before_2fa(build(:user))
        get :show

        expect(response).to redirect_to authentication_methods_setup_url
      end
    end

    context 'when phone is sole configured mfa and full phone vendor outage' do
      before do
        allow_any_instance_of(VendorStatus).to receive(:all_phone_vendor_outage?).and_return(true)
      end

      it 'redirects to vendor outage page' do
        stub_sign_in_before_2fa(create(:user, :with_phone, with: { phone: '+1 (703) 555-1212' }))

        get :show

        expect(response).to redirect_to vendor_outage_path(from: :two_factor_authentication)
      end
    end

    context 'when SP requires PIV/CAC' do
      let(:user) { create(:user, :signed_up) }

      before do
        stub_sign_in(user)
        controller.session[:sp] = { aal3_requested: true, piv_cac_requested: true }
      end

      it 'redirects to MFA setup if no PIV/CAC is enabled' do
        get :show

        expect(response).to redirect_to(authentication_methods_setup_url)
      end
    end
  end

  describe '#send_code' do
    context 'when selecting SMS OTP delivery' do
      before do
        @user = create(:user, :with_phone)
        sign_in_before_2fa(@user)
        @old_otp = subject.current_user.direct_otp
        allow(Telephony).to receive(:send_authentication_otp).and_call_original
      end

      it 'sends OTP via SMS for sign in' do
        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }

        expect(Telephony).to have_received(:send_authentication_otp).with(
          otp: subject.current_user.direct_otp,
          to: MfaContext.new(subject.current_user).phone_configurations.first.phone,
          expiration: 10,
          channel: :sms,
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false),
        )
      end

      it 'tracks the analytics events' do
        stub_analytics

        analytics_hash = {
          success: true,
          errors: {},
          otp_delivery_preference: 'sms',
          resend: 'true',
          context: 'authentication',
          country_code: 'US',
          area_code: '202',
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
        }

        expect(@analytics).to receive(:track_event).
          ordered.
          with('OTP: Delivery Selection', analytics_hash)
        expect(@analytics).to receive(:track_event).
          ordered.
          with('Telephony: OTP sent', hash_including(
            resend: 'true', success: true, otp_delivery_preference: 'sms',
          ))

        get :send_code, params: { otp_delivery_selection_form:
                                  { otp_delivery_preference: 'sms', resend: 'true' } }
      end

      it 'tracks the verification attempt event' do
        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_sent).
          with(phone_number: '+12025551212', reauthentication: false, success: true)

        get :send_code, params: { otp_delivery_selection_form:
          { otp_delivery_preference: 'sms' } }
      end

      it 'calls OtpRateLimiter#exceeded_otp_send_limit? and #increment' do
        otp_rate_limiter = instance_double(OtpRateLimiter)
        allow(OtpRateLimiter).to receive(:new).
          with(phone: MfaContext.new(@user).phone_configurations.first.phone,
               user: @user, phone_confirmed: true).
          and_return(otp_rate_limiter)

        expect(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).twice
        expect(otp_rate_limiter).to receive(:increment)

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
      end

      it 'marks the user as locked out after too many attempts' do
        expect(@user.second_factor_locked_at).to be_nil

        freeze_time do
          (IdentityConfig.store.otp_delivery_blocklist_maxretry + 1).times do
            get :send_code, params: {
              otp_delivery_selection_form: {
                otp_delivery_preference: 'sms',
                otp_make_default_number: nil,
              },
            }
          end

          expect(@user.reload.second_factor_locked_at).to eq Time.zone.now
        end
      end

      context 'when the phone has been marked as opted out in the DB' do
        before do
          PhoneNumberOptOut.mark_opted_out(@user.phone_configurations.first.phone)
        end

        it 'does not send an OTP' do
          expect(Telephony).to_not receive(:send_authentication_otp)
          expect(Telephony).to_not receive(:send_confirmation_otp)

          get :send_code, params: {
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' },
          }
        end
      end

      context 'when Pinpoint throws an opt-out error' do
        before do
          @user.phone_configurations.first.tap do |phone_config|
            phone_config.phone = Telephony::Test::ErrorSimulator::OPT_OUT_PHONE_NUMBER
            phone_config.save!
          end
        end

        it 'redirects to the opt in controller' do
          get :send_code, params: {
            otp_delivery_selection_form: { otp_delivery_preference: 'sms' },
          }

          opt_out = PhoneNumberOptOut.create_or_find_with_phone(
            Telephony::Test::ErrorSimulator::OPT_OUT_PHONE_NUMBER,
          )

          expect(response).to redirect_to(
            login_two_factor_sms_opt_in_path(opt_out_uuid: opt_out),
          )
        end
      end
    end

    context 'when selecting voice OTP delivery' do
      before do
        user = create(:user, :signed_up, otp_delivery_preference: 'voice')
        sign_in_before_2fa(user)
        @old_otp = subject.current_user.direct_otp
        allow(Telephony).to receive(:send_authentication_otp).and_call_original
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
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
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
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
        }

        expect(@analytics).to receive(:track_event).
          ordered.
          with('OTP: Delivery Selection', analytics_hash)
        expect(@analytics).to receive(:track_event).
          ordered.
          with('Telephony: OTP sent', hash_including(
            success: true,
            otp_delivery_preference: 'voice',
            country_code: 'US',
            telephony_response: hash_including(
              origination_phone_number: Telephony::Test::VoiceSender::ORIGINATION_PHONE_NUMBER,
            ),
          ))

        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'voice',
                                         otp_make_default_number: nil },
        }
      end

      context 'when selecting specific phone configuration' do
        before do
          user = create(:user, :signed_up)
          sign_in_before_2fa(user)
        end
      end

      it 'redirects to two factor options path with invalid id' do
        controller.user_session[:phone_id] = 0

        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'voice' },
        }

        expect(response).to redirect_to(login_two_factor_options_path)
      end
    end

    context 'phone is not confirmed' do
      before do
        @user = create(:user)
        @unconfirmed_phone = '+1 (202) 555-1213'
      end

      it 'sends OTP inline when confirming phone' do
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        subject.user_session[:unconfirmed_phone] = @unconfirmed_phone

        allow(Telephony).to receive(:send_confirmation_otp).and_call_original

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }

        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: subject.current_user.direct_otp,
          to: @unconfirmed_phone,
          expiration: 10,
          channel: :sms,
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
        )
      end

      it 'tracks the enrollment attempt event' do
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        subject.user_session[:unconfirmed_phone] = @unconfirmed_phone

        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:mfa_enroll_phone_otp_sent).
          with({ phone_number: '+12025551213', success: true })

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
      end

      it 'rate limits confirmation OTPs on sign up' do
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)

        freeze_time do
          (IdentityConfig.store.phone_confirmation_max_attempts + 1).times do
            subject.user_session[:unconfirmed_phone] = '+1 (202) 555-1213'
            get :send_code,
                params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
          end

          timeout = distance_of_time_in_words(
            Throttle.attempt_window_in_minutes(:phone_confirmation).minutes,
          )

          expect(flash[:error]).to eq(
            I18n.t(
              'errors.messages.phone_confirmation_throttled',
              timeout: timeout,
            ),
          )
          expect(response).to redirect_to authentication_methods_setup_url
        end
      end

      it 'rate limits confirmation OTPs when adding number to existing account' do
        stub_sign_in(@user)
        subject.user_session[:context] = 'confirmation'
        allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)

        freeze_time do
          (IdentityConfig.store.phone_confirmation_max_attempts + 1).times do
            subject.user_session[:unconfirmed_phone] = '+1 (202) 555-1213'
            get :send_code,
                params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
          end

          timeout = distance_of_time_in_words(
            Throttle.attempt_window_in_minutes(:phone_confirmation).minutes,
          )

          expect(flash[:error]).to eq(
            I18n.t(
              'errors.messages.phone_confirmation_throttled',
              timeout: timeout,
            ),
          )
          expect(response).to redirect_to account_url
        end
      end

      it 'flashes an sms error when the telephony gem responds with an sms error' do
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        subject.user_session[:unconfirmed_phone] = @unconfirmed_phone
        subject.user_session[:unconfirmed_phone] = '+1 (225) 555-1000'

        get :send_code, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }

        expect(flash[:error]).to eq(I18n.t('telephony.error.friendly_message.generic'))
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
