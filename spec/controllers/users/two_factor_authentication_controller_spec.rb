require 'rails_helper'

RSpec.describe Users::TwoFactorAuthenticationController do
  include ActionView::Helpers::DateHelper
  include UserAgentHelper

  let(:otp_preference_sms) { { otp_delivery_preference: 'sms' } }
  let(:user) { create(:user, :fully_registered) }

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user,
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
      before do
        sign_in user
      end

      it 'redirects to the profile' do
        get :index

        expect(response).to redirect_to(account_url)
      end
    end

    context 'when the user is fully authenticated and the context is not authentication' do
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
    let(:with_default_phone) { { with: { phone: '+1 (703) 555-1212' } } }
    context 'when user is piv/cac enabled' do
      it 'renders the piv/cac entry screen' do
        allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
        user = create(:user, :with_piv_or_cac)
        stub_sign_in_before_2fa(user)

        get :show

        expect(response).to redirect_to login_two_factor_piv_cac_path
      end

      it 'redirects to phone when on mobile and user has phone' do
        allow(controller).to receive(:mobile?).and_return(true)
        user = create(:user, :with_phone, :with_piv_or_cac)
        stub_sign_in_before_2fa(user)

        request.headers['User-Agent'] = mobile_user_agent
        get :show

        expect(response).to redirect_to login_otp_path(otp_delivery_preference: :sms)
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
    end

    context 'when user is authenticated with a remembered device via phone' do
      it 'does redirect to the profile' do
        stub_analytics
        user = create(:user, :with_phone, **with_default_phone)
        stub_sign_in_before_2fa(user)

        time1 = Time.zone.local(2022, 12, 13, 0, 0, 0)
        cookies.encrypted[:remember_device] = {
          value: RememberDeviceCookie.new(user_id: user.id, created_at: time1).to_json,
          expires: time1 + 10.seconds,
        }

        travel_to(time1 + 1.second) do
          get :show

          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            { authentication_type: :device_remembered },
          )
          expect(@analytics).to have_logged_event(
            'Remembered device used for authentication',
            { cookie_created_at: time1, cookie_age_seconds: 1 },
          )
        end

        expect(Telephony::Test::Message.messages.length).to eq(0)
        expect(Telephony::Test::Call.calls.length).to eq(0)
        expect(response).to redirect_to(account_path)
      end
    end

    context 'when user is authenticated with an expired remembered device' do
      it 'redirects to 2FA' do
        user = create(:user, :with_phone, **with_default_phone)
        stub_sign_in_before_2fa(user)

        freeze_time do
          cookies.encrypted[:remember_device] = {
            value: RememberDeviceCookie.new(user_id: user.id, created_at: Time.zone.now).to_json,
            expires: 2.days.ago,
          }

          get :show
        end

        expect(response).to redirect_to(
          login_two_factor_path(**otp_preference_sms),
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
    end

    context 'when user has webauthn' do
      let(:user) { create(:user, :with_webauthn) }

      before do
        stub_sign_in_before_2fa(user)
      end

      it 'redirects to webauthn verification' do
        get :show

        expect(response).to redirect_to login_two_factor_webauthn_path
      end

      context 'when user has platform webauthn' do
        let(:user) { create(:user, :with_webauthn_platform) }

        it 'redirects to webauthn verification with the platform parameter' do
          get :show

          expect(response).to redirect_to login_two_factor_webauthn_path(platform: true)
        end

        context 'when session value indicates no device platform support available' do
          before do
            controller.user_session[:platform_authenticator_available] = false
          end

          it 'redirects to mfa options page' do
            get :show

            expect(response).to redirect_to login_two_factor_options_path
          end
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

    context 'when the user has already set up 2FA' do
      it 'sends OTP via otp_delivery_preference and prompts for OTP' do
        stub_sign_in_before_2fa(create(:user, :with_phone, **with_default_phone))

        get :show

        expect(Telephony::Test::Message.messages.length).to eq(1)
        expect(Telephony::Test::Call.calls.length).to eq(0)
        expect(response)
          .to redirect_to login_two_factor_path(**otp_preference_sms)
      end

      context 'when no options are enabled and available for use' do
        before do
          allow_any_instance_of(OutageStatus).to receive(:any_phone_vendor_outage?).and_return(true)
        end

        it 'redirects to mfa options page' do
          stub_sign_in_before_2fa(create(:user, :with_phone, **with_default_phone))

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
        allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).and_return(true)
      end

      it 'redirects to vendor outage page' do
        stub_sign_in_before_2fa(create(:user, :with_phone, **with_default_phone))

        get :show

        expect(response).to redirect_to vendor_outage_path(from: :two_factor_authentication)
      end
    end

    context 'when SP requires PIV/CAC' do
      let(:service_provider) { create(:service_provider) }

      before do
        stub_sign_in(user)
        controller.session[:sp] = {
          issuer: service_provider.issuer,
          acr_values: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
        }
      end

      it 'redirects to MFA setup if no PIV/CAC is enabled' do
        get :show

        expect(response).to redirect_to(authentication_methods_setup_url)
      end
    end
  end

  describe '#send_code' do
    let(:otp_delivery_form_sms) { { otp_delivery_selection_form: otp_preference_sms } }
    context 'when selecting SMS OTP delivery' do
      let(:valid_phone_number) { { phone_number: '+12025551212' } }
      let(:default_parameters) do
        { **valid_phone_number, otp_delivery_method: 'sms' }
      end
      let(:success_parameters) { { success: true, **default_parameters } }

      before do
        @user = create(:user, :with_phone)
        sign_in_before_2fa(@user)
        @old_otp = controller.current_user.direct_otp
        allow(Telephony).to receive(:send_authentication_otp).and_call_original
      end

      it 'sends OTP via SMS for sign in' do
        get :send_code, params: otp_delivery_form_sms

        phone = MfaContext.new(subject.current_user).phone_configurations.first.phone
        parsed_phone = Phonelib.parse(phone)

        expect(Telephony).to have_received(:send_authentication_otp).with(
          otp: subject.current_user.direct_otp,
          to: phone,
          expiration: 10,
          channel: :sms,
          otp_format: 'digit',
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
          extra_metadata: {
            area_code: parsed_phone.area_code,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            resend: nil,
          },
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(**otp_preference_sms),
        )
      end

      it 'tracks the analytics events' do
        stub_analytics

        get :send_code, params: {
          otp_delivery_selection_form: { **otp_preference_sms, resend: 'true' },
        }

        expect(@analytics).to have_logged_event(
          'OTP: Delivery Selection',
          success: true,
          **otp_preference_sms,
          resend: true,
          context: 'authentication',
          country_code: 'US',
          area_code: '202',
        )
        expect(@analytics).to have_logged_event(
          'Telephony: OTP sent',
          hash_including(
            resend: true, success: true, **otp_preference_sms,
            adapter: :test
          ),
        )
      end

      it 'calls OtpRateLimiter#exceeded_otp_send_limit? and #increment' do
        otp_rate_limiter = instance_double(OtpRateLimiter)
        allow(OtpRateLimiter).to receive(:new)
          .with(phone: MfaContext.new(@user).phone_configurations.first.phone,
                user: @user, phone_confirmed: true)
          .and_return(otp_rate_limiter)

        expect(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).twice
        expect(otp_rate_limiter).to receive(:increment)

        get :send_code, params: otp_delivery_form_sms
      end

      it 'marks the user as locked out after too many attempts' do
        expect(@user.second_factor_locked_at).to be_nil

        allow(OtpRateLimiter).to receive(:exceeded_otp_send_limit?)
          .and_return(true)

        stub_attempts_tracker
        expect(@attempts_api_tracker).to receive(:mfa_login_phone_otp_sent_rate_limited).with(
          phone_number: Phonelib.parse(MfaContext.new(@user).phone_configurations.first.phone).e164,
        )

        freeze_time do
          (IdentityConfig.store.otp_delivery_blocklist_maxretry + 1).times do
            get :send_code, params: {
              otp_delivery_selection_form: {
                **otp_preference_sms,
                otp_make_default_number: nil,
              },
            }
          end

          expect(@user.reload.second_factor_locked_at).to eq Time.zone.now
        end
      end

      context 'with recaptcha phone assessment id in session' do
        let(:assessment_id) { 'projects/project-id/assessments/assessment-id' }

        subject(:response) do
          get :send_code, params: {
            otp_delivery_selection_form: {
              **otp_preference_sms,
              otp_make_default_number: nil,
            },
          }
        end

        before do
          stub_analytics
          controller.user_session[:phone_recaptcha_assessment_id] = assessment_id
        end

        it 'annotates recaptcha assessment with initiated 2fa' do
          recaptcha_annotation = {
            assessment_id:,
            reason: RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
          }
          expect(RecaptchaAnnotator).to receive(:annotate).once
            .with(**recaptcha_annotation)
            .and_return(recaptcha_annotation)

          response

          expect(@analytics).to have_logged_event(
            'Telephony: OTP sent',
            hash_including(recaptcha_annotation:),
          )
        end
      end

      context 'when the phone has been marked as opted out in the DB' do
        before do
          PhoneNumberOptOut.mark_opted_out(@user.phone_configurations.first.phone)
        end

        it 'does not send an OTP' do
          expect(Telephony).to_not receive(:send_authentication_otp)
          expect(Telephony).to_not receive(:send_confirmation_otp)

          get :send_code, params: otp_delivery_form_sms
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
          get :send_code, params: otp_delivery_form_sms

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
        user = create(:user, :fully_registered, otp_delivery_preference: 'voice')
        sign_in_before_2fa(user)
        @old_otp = subject.current_user.direct_otp
        allow(Telephony).to receive(:send_authentication_otp).and_call_original
      end

      it 'sends OTP via voice' do
        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'voice' },
        }
        phone = MfaContext.new(subject.current_user).phone_configurations.first.phone
        parsed_phone = Phonelib.parse(phone)

        expect(Telephony).to have_received(:send_authentication_otp).with(
          otp: subject.current_user.direct_otp,
          to: phone,
          expiration: 10,
          channel: :voice,
          otp_format: 'digit',
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
          extra_metadata: {
            area_code: parsed_phone.area_code,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            resend: nil,
          },
        )
        expect(subject.current_user.direct_otp).not_to eq(@old_otp)
        expect(subject.current_user.direct_otp).not_to be_nil
        expect(response).to redirect_to(
          login_two_factor_path(otp_delivery_preference: 'voice'),
        )
      end

      it 'tracks the event' do
        stub_analytics

        get :send_code, params: {
          otp_delivery_selection_form: { otp_delivery_preference: 'voice',
                                         otp_make_default_number: nil },
        }

        expect(@analytics).to have_logged_event(
          'OTP: Delivery Selection',
          success: true,
          otp_delivery_preference: 'voice',
          resend: false,
          context: 'authentication',
          country_code: 'US',
          area_code: '202',
        )
        expect(@analytics).to have_logged_event(
          'Telephony: OTP sent',
          hash_including(
            success: true,
            otp_delivery_preference: 'voice',
            adapter: :test,
            country_code: 'US',
            telephony_response: hash_including(
              origination_phone_number: Telephony::Test::VoiceSender::ORIGINATION_PHONE_NUMBER,
            ),
          ),
        )
      end

      context 'when selecting specific phone configuration' do
        before do
          user = create(:user, :fully_registered)
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
        parsed_phone = Phonelib.parse(@unconfirmed_phone)

        allow(Telephony).to receive(:send_confirmation_otp).and_call_original

        get :send_code, params: otp_delivery_form_sms

        expect(Telephony).to have_received(:send_confirmation_otp).with(
          otp: subject.current_user.direct_otp,
          to: @unconfirmed_phone,
          expiration: 10,
          channel: :sms,
          otp_format: 'digit',
          otp_length: '6',
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
          extra_metadata: {
            area_code: parsed_phone.area_code,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            resend: nil,
          },
        )
      end

      it 'rate limits confirmation OTPs on sign up' do
        parsed_phone = Phonelib.parse(@unconfirmed_phone)
        stub_analytics
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)

        freeze_time do
          IdentityConfig.store.phone_confirmation_max_attempts.times do
            subject.user_session[:unconfirmed_phone] = @unconfirmed_phone
            get :send_code, params: otp_delivery_form_sms
          end

          timeout = distance_of_time_in_words(
            RateLimiter.attempt_window_in_minutes(:phone_confirmation).minutes,
          )

          expect(flash[:error]).to eq(
            I18n.t(
              'errors.messages.phone_confirmation_limited',
              timeout: timeout,
            ),
          )
          expect(response).to redirect_to authentication_methods_setup_url
        end
        expect(@analytics).to have_logged_event(
          'Rate Limit Reached',
          country_code: parsed_phone.country,
          limiter_type: :phone_confirmation,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        )
      end

      it 'rate limits between OTPs' do
        parsed_phone = Phonelib.parse(@unconfirmed_phone)
        stub_analytics
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        allow(IdentityConfig.store).to receive(:short_term_phone_otp_max_attempts).and_return(2)
        allow(IdentityConfig.store).to receive(:short_term_phone_otp_max_attempt_window_in_seconds)
          .and_return(5)

        freeze_time do
          IdentityConfig.store.short_term_phone_otp_max_attempts.times do
            subject.user_session[:unconfirmed_phone] = @unconfirmed_phone
            get :send_code, params: otp_delivery_form_sms
          end

          timeout = distance_of_time_in_words(
            RateLimiter.attempt_window_in_minutes(:short_term_phone_otp).minutes,
          )

          expect(flash[:error]).to eq(
            I18n.t(
              'errors.messages.phone_confirmation_limited',
              timeout: timeout,
            ),
          )
          expect(response).to redirect_to login_two_factor_url(otp_delivery_preference: 'sms')
        end

        expect(@analytics).to have_logged_event(
          'Rate Limit Reached',
          context: 'confirmation',
          country_code: parsed_phone.country,
          limiter_type: :short_term_phone_otp,
          otp_delivery_preference: 'sms',
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        )
      end

      it 'marks the user as locked out after too many attempts on sign up' do
        sign_in_before_2fa(@user)
        subject.user_session[:context] = 'confirmation'
        subject.user_session[:unconfirmed_phone] = '+1 (202) 555-1213'

        expect(@user.second_factor_locked_at).to be_nil

        allow(OtpRateLimiter).to receive(:exceeded_otp_send_limit?)
          .and_return(true)

        stub_attempts_tracker
        expect(@attempts_api_tracker).to receive(:mfa_enroll_phone_otp_sent_rate_limited)
          .with(phone_number: Phonelib.parse(subject.user_session[:unconfirmed_phone]).e164)

        freeze_time do
          (IdentityConfig.store.otp_delivery_blocklist_maxretry + 1).times do
            get :send_code, params: {
              otp_delivery_selection_form: {
                **otp_preference_sms,
                otp_make_default_number: nil,
              },
            }
          end

          expect(@user.reload.second_factor_locked_at).to eq Time.zone.now
        end
      end

      it 'rate limits confirmation OTPs when adding number to existing account' do
        stub_sign_in(@user)
        subject.user_session[:context] = 'confirmation'
        allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)

        freeze_time do
          (IdentityConfig.store.phone_confirmation_max_attempts + 1).times do
            subject.user_session[:unconfirmed_phone] = '+1 (202) 555-1213'
            get :send_code, params: otp_delivery_form_sms
          end

          timeout = distance_of_time_in_words(
            RateLimiter.attempt_window_in_minutes(:phone_confirmation).minutes,
          )

          expect(flash[:error]).to eq(
            I18n.t(
              'errors.messages.phone_confirmation_limited',
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

        get :send_code, params: otp_delivery_form_sms

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

        expect(response).to redirect_to login_two_factor_url(**otp_preference_sms)
      end
    end
  end
end
