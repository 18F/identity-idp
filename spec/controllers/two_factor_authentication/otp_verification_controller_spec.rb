require 'rails_helper'

RSpec.describe TwoFactorAuthentication::OtpVerificationController do
  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        sign_in_before_2fa
        subject.user_session[:mfa_selections] = ['sms']
      end

      context 'when FeatureManagement.prefill_otp_codes? is true' do
        it 'sets code_value on presenter to correct OTP value' do
          presenter_data = attributes_for(:generic_otp_presenter)
          TwoFactorAuthCode::PhoneDeliveryPresenter.new(
            data: presenter_data,
            view: ActionController::Base.new.view_context,
            service_provider: nil,
          )
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

          get :show, params: { otp_delivery_preference: 'sms' }

          expect(assigns(:presenter).code_value).to eq(subject.current_user.direct_otp)
        end
      end

      context 'when FeatureManagement.prefill_otp_codes? is false' do
        it 'does not set @code_value' do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(false)
          get :show, params: { otp_delivery_preference: 'sms' }

          expect(assigns(:code_value)).to be_nil
        end
      end

      context 'when the user has an invalid phone number in the session' do
        it 'redirects to homepage' do
          subject.user_session[:phone_id] = 0

          get :show, params: { otp_delivery_preference: 'sms' }
          expect(response).to redirect_to new_user_session_path
        end
      end
    end

    it 'tracks the page visit and context' do
      user = build_stubbed(:user, :with_phone, with: { phone: '+1 (703) 555-0100' })
      stub_sign_in_before_2fa(user)
      parsed_phone = Phonelib.parse(subject.current_user.default_phone_configuration.phone)
      subject.user_session[:mfa_selections] = ['sms']
      stub_analytics

      get :show, params: { otp_delivery_preference: 'sms' }

      expect(@analytics).to have_logged_event(
        'Multi-Factor Authentication: enter OTP visited',
        context: 'authentication',
        multi_factor_auth_method: 'sms',
        confirmation_for_add_phone: false,
        phone_configuration_id: subject.current_user.default_phone_configuration.id,
        area_code: parsed_phone.area_code,
        country_code: parsed_phone.country,
        phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        enabled_mfa_methods_count: 1,
        in_account_creation_flow: false,
      )
    end

    context 'when there is a sign_in_recaptcha_assessment_id in the session' do
      let(:assessment_id) { 'projects/project-id/assessments/assessment-id' }

      it 'annotates the assessment with INITIATED_TWO_FACTOR and logs the annotation' do
        user = build_stubbed(:user, :with_phone, with: { phone: '+1 (703) 555-0100' })
        stub_sign_in_before_2fa(user)
        stub_analytics

        recaptcha_annotation = {
          assessment_id:,
          reason: RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
        }

        controller.session[:sign_in_recaptcha_assessment_id] = assessment_id

        expect(RecaptchaAnnotator).to receive(:annotate)
          .with(**recaptcha_annotation)
          .and_return(recaptcha_annotation)

        get :show, params: { otp_delivery_preference: 'sms' }

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication: enter OTP visited',
          hash_including(recaptcha_annotation:),
        )
      end
    end

    context 'when the user is registering a new landline phone_number with SMS preference' do
      render_views
      it 'display a landline warning' do
        user = build_stubbed(:user)
        stub_sign_in_before_2fa(user)
        controller.user_session[:unconfirmed_phone] = '+1 (703) 555-0100'
        controller.user_session[:context] = 'confirmation'
        controller.user_session[:phone_type] = 'landline'
        controller.user_session[:mfa_selections] = ['sms']

        get :show, params: { otp_delivery_preference: 'sms' }

        expect(response.body).to include(
          t(
            'two_factor_authentication.otp_delivery_preference.landline_warning_html',
            phone_setup_path: controller.view_context.link_to(
              t('two_factor_authentication.otp_delivery_preference.phone_call'),
              phone_setup_path(otp_delivery_preference: 'voice'),
            ),
          ),
        )
      end
    end

    context 'when there is no session (signed out or locked out), and the user reloads the page' do
      it 'redirects to the home page' do
        expect(controller.user_session).to be_nil

        get :show, params: { otp_delivery_preference: 'sms' }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it 'redirects to phone setup page if user does not have a phone yet' do
      user = build_stubbed(:user)
      stub_sign_in_before_2fa(user)

      get :show, params: { otp_delivery_preference: 'sms' }

      expect(response).to redirect_to(phone_setup_url)
    end

    it 'redirects to authentication if user is fully registered but does not have a phone' do
      user = create(:user, :with_authentication_app)
      stub_sign_in_before_2fa(user)

      get :show, params: { otp_delivery_preference: 'sms' }

      expect(response).to redirect_to(user_two_factor_authentication_url)
    end
  end

  describe '#create' do
    let(:user) { create(:user, :with_phone) }
    let(:parsed_phone) { Phonelib.parse(user.default_phone_configuration.phone) }
    context 'when the user enters an invalid OTP during authentication context' do
      subject(:response) { post :create, params: { code: '12345', otp_delivery_preference: 'sms' } }

      before do
        sign_in_before_2fa(user)
        controller.user_session[:mfa_selections] = ['sms']
        expect(controller.current_user.reload.second_factor_attempts_count).to eq 0

        stub_analytics
        stub_attempts_tracker
      end

      it 'logs analytics' do
        expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
          mfa_device_type: 'otp',
          success: false,
          failure_reason: { code: [:wrong_length, :incorrect] },
          reauthentication: false,
        )

        response

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication',
          success: false,
          error_details: { code: { wrong_length: true, incorrect: true } },
          confirmation_for_add_phone: false,
          context: 'authentication',
          multi_factor_auth_method: 'sms',
          multi_factor_auth_method_created_at: user.default_phone_configuration.created_at
            .strftime('%s%L'),
          new_device: true,
          phone_configuration_id: user.default_phone_configuration.id,
          area_code: parsed_phone.area_code,
          country_code: parsed_phone.country,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
          enabled_mfa_methods_count: 1,
          in_account_creation_flow: false,
          attempts: 1,
        )
      end

      it 'increments second_factor_attempts_count' do
        response

        expect(controller.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the OTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        response

        expect(flash[:error]).to eq t('two_factor_authentication.invalid_otp')
      end

      it 'does not set auth_method and requires 2FA' do
        response

        expect(controller.user_session[:auth_events]).to eq nil
        expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq true
      end

      it 'records unsuccessful 2fa event' do
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        response
      end
    end

    context 'when the user enters an invalid OTP during reauthentication context' do
      it 'increments second_factor_attempts_count' do
        sign_in_before_2fa(user)
        controller.user_session[:context] = 'reauthentication'

        post :create, params: { code: '12345', otp_delivery_preference: 'sms' }

        expect(controller.current_user.reload.second_factor_attempts_count).to eq 1
      end
    end

    context 'when the user has reached the max number of OTP attempts' do
      let(:user) do
        create(
          :user,
          :fully_registered,
          :with_phone,
          second_factor_attempts_count:
            IdentityConfig.store.login_otp_confirmation_max_attempts - 1,
        )
      end

      before do
        sign_in_before_2fa(user)
        controller.user_session[:mfa_selections] = ['sms']

        stub_analytics
        stub_attempts_tracker
      end

      context 'with authentication context' do
        it 'tracks the event' do
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'otp',
            success: false,
            failure_reason: { code: [:wrong_length, :incorrect] },
            reauthentication: false,
          )

          expect(@attempts_api_tracker).to receive(:mfa_submission_code_rate_limited).with(
            mfa_device_type: 'otp',
          )

          expect(PushNotification::HttpPush).to receive(:deliver)
            .with(PushNotification::MfaLimitAccountLockedEvent.new(user: controller.current_user))

          post :create, params: { code: '12345', otp_delivery_preference: 'sms' }

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: false,
            error_details: { code: { wrong_length: true, incorrect: true } },
            confirmation_for_add_phone: false,
            context: 'authentication',
            multi_factor_auth_method: 'sms',
            multi_factor_auth_method_created_at: user.default_phone_configuration.created_at
              .strftime('%s%L'),
            new_device: true,
            phone_configuration_id: user.default_phone_configuration.id,
            area_code: parsed_phone.area_code,
            country_code: parsed_phone.country,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: false,
            attempts: 1,
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication: max attempts reached',
          )
        end
      end

      context 'with confirmation context' do
        before do
          allow(UserSessionContext).to receive(:confirmation_context?).and_return true
        end

        it 'tracks the event' do
          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'otp',
            success: false,
            failure_reason: { code: [:wrong_length, :incorrect] },
            reauthentication: false,
          )
          expect(@attempts_api_tracker).to receive(:mfa_enroll_code_rate_limited).with(
            mfa_device_type: 'otp',
          )

          expect(PushNotification::HttpPush).to receive(:deliver)
            .with(PushNotification::MfaLimitAccountLockedEvent.new(user: controller.current_user))

          post :create, params: { code: '12345', otp_delivery_preference: 'sms' }

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: false,
            error_details: { code: { wrong_length: true, incorrect: true } },
            confirmation_for_add_phone: false,
            context: 'authentication',
            multi_factor_auth_method: 'sms',
            multi_factor_auth_method_created_at: user.default_phone_configuration.created_at
              .strftime('%s%L'),
            new_device: true,
            phone_configuration_id: user.default_phone_configuration.id,
            area_code: parsed_phone.area_code,
            country_code: parsed_phone.country,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: false,
            attempts: 2,
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication: max attempts reached',
          )
        end
      end
    end

    context 'when the user enters a valid OTP' do
      before do
        sign_in_before_2fa(user)
        subject.user_session[:mfa_selections] = ['sms']
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'redirects to the profile' do
        post :create, params: {
          code: subject.current_user.reload.direct_otp,
          otp_delivery_preference: 'sms',
        }

        expect(response).to redirect_to account_path
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update(second_factor_attempts_count: 1)
        post :create, params: {
          code: subject.current_user.reload.direct_otp,
          otp_delivery_preference: 'sms',
        }

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        stub_attempts_tracker

        expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
          mfa_device_type: 'otp',
          success: true,
          failure_reason: nil,
          reauthentication: false,
        )

        expect(controller).to receive(:handle_valid_verification_for_authentication_context)
          .with(auth_method: TwoFactorAuthenticatable::AuthMethod::SMS)
          .and_call_original

        freeze_time do
          post :create, params: {
            code: subject.current_user.reload.direct_otp,
            otp_delivery_preference: 'sms',
          }

          expect(subject.user_session[:auth_events]).to eq(
            [
              {
                auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
                at: Time.zone.now,
              },
            ],
          )
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
        end

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication',
          success: true,
          confirmation_for_add_phone: false,
          context: 'authentication',
          multi_factor_auth_method: 'sms',
          multi_factor_auth_method_created_at: user.default_phone_configuration.created_at
            .strftime('%s%L'),
          new_device: true,
          phone_configuration_id: user.default_phone_configuration.id,
          area_code: parsed_phone.area_code,
          country_code: parsed_phone.country,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
          enabled_mfa_methods_count: 1,
          in_account_creation_flow: false,
          attempts: 1,
        )
        expect(@analytics).to have_logged_event(
          'User marked authenticated',
          authentication_type: :valid_2fa,
        )
      end

      context 'with reauthentication context' do
        before do
          controller.user_session[:context] = 'reauthentication'
        end

        it 'tracks the valid authentication event' do
          stub_analytics
          stub_attempts_tracker

          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'otp',
            success: true,
            failure_reason: nil,
            reauthentication: true,
          )

          freeze_time do
            post :create, params: {
              code: subject.current_user.reload.direct_otp,
              otp_delivery_preference: 'sms',
            }

            expect(subject.user_session[:auth_events]).to eq(
              [
                {
                  auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
                  at: Time.zone.now,
                },
              ],
            )
            expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
          end

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: true,
            confirmation_for_add_phone: false,
            context: 'reauthentication',
            multi_factor_auth_method: 'sms',
            multi_factor_auth_method_created_at: user.default_phone_configuration.created_at
              .strftime('%s%L'),
            new_device: true,
            phone_configuration_id: user.default_phone_configuration.id,
            area_code: parsed_phone.area_code,
            country_code: parsed_phone.country,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: false,
            attempts: 1,
          )
          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            authentication_type: :valid_2fa,
          )
        end
      end

      context 'with existing device' do
        before do
          allow(controller).to receive(:new_device?).and_return(false)
        end

        it 'tracks new device value' do
          stub_analytics
          stub_attempts_tracker

          expect(@attempts_api_tracker).to receive(:mfa_login_auth_submitted).with(
            mfa_device_type: 'otp',
            success: true,
            failure_reason: nil,
            reauthentication: false,
          )

          post :create, params: {
            code: subject.current_user.reload.direct_otp,
            otp_delivery_preference: 'sms',
          }

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            hash_including(new_device: false),
          )
        end
      end

      context "with a leading '#' sign" do
        it 'redirects to the profile' do
          post :create, params: {
            code: "##{subject.current_user.reload.direct_otp}",
            otp_delivery_preference: 'sms',
          }

          expect(response).to redirect_to account_path
        end
      end

      context 'with remember_device in the params' do
        it 'saves an encrypted cookie' do
          freeze_time do
            expect(cookies.encrypted[:remember_device]).to eq nil
            post(
              :create,
              params: {
                code: subject.current_user.direct_otp,
                otp_delivery_preference: 'sms',
                remember_device: '1',
              },
            )

            remember_device_cookie = RememberDeviceCookie.from_json(
              cookies.encrypted[:remember_device],
            )
            expiration_interval = IdentityConfig.store.remember_device_expiration_hours_aal_1.hours
            expect(
              remember_device_cookie.valid_for_user?(
                user: subject.current_user,
                expiration_interval: expiration_interval,
              ),
            ).to eq true
          end
        end
      end

      context 'without remember_device in the params' do
        it 'does not save an encrypted cookie' do
          post(
            :create,
            params: {
              code: subject.current_user.direct_otp,
              otp_delivery_preference: 'sms',
            },
          )

          expect(cookies[:remember_device]).to be_nil
        end
      end
    end

    context 'when the user lockout period expires' do
      before do
        sign_in_before_2fa(user)
        lockout_period = IdentityConfig.store.lockout_period_in_minutes.minutes
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - lockout_period - 1.second,
          second_factor_attempts_count: 3,
        )
      end

      describe 'when user submits an invalid OTP' do
        before do
          post :create, params: { code: '12345', otp_delivery_preference: 'sms' }
        end

        it 'increments attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a valid OTP' do
        before do
          post :create, params: {
            code: subject.current_user.direct_otp,
            otp_delivery_preference: 'sms',
          }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end

    context 'phone confirmation' do
      let(:user) { create(:user, :fully_registered) }
      before do
        sign_in_as_user(user)
        controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
        controller.user_session[:unconfirmed_phone] = '+1 (703) 555-5555'
        controller.user_session[:context] = 'confirmation'

        @previous_phone_confirmed_at =
          MfaContext.new(controller.current_user).phone_configurations.first&.confirmed_at

        controller.current_user.create_direct_otp

        stub_analytics
        stub_attempts_tracker

        allow(controller).to receive(:create_user_event)

        @mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)

        controller.current_user.email_addresses.each do |email_address|
          allow(UserMailer).to receive(:phone_added)
            .with(controller.current_user, email_address, disavowal_token: instance_of(String))
            .and_return(@mailer)
        end
        @previous_phone = MfaContext.new(controller.current_user).phone_configurations.first&.phone
      end

      context 'user is fully authenticated and has an existing phone number' do
        context 'user enters a valid code' do
          before do
            subject.user_session[:mfa_selections] = ['sms']
            subject.user_session[:in_account_creation_flow] = true
            phone_configuration = MfaContext.new(subject.current_user).phone_configurations.last
            phone_id = phone_configuration.id
            parsed_phone = Phonelib.parse(phone_configuration.phone)
            phone_configuration_created_at = controller.current_user
              .default_phone_configuration.created_at

            controller.user_session[:phone_id] = phone_id
            expect(@attempts_api_tracker).to receive(:mfa_enrolled).with(
              success: true,
              mfa_device_type: 'phone',
              otp_delivery_method: 'sms',
              phone_number: parsed_phone.e164,
            )

            post(
              :create,
              params: {
                code: subject.current_user.direct_otp,
                otp_delivery_preference: 'sms',
              },
            )

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication Setup',
              success: true,
              confirmation_for_add_phone: true,
              context: 'confirmation',
              multi_factor_auth_method: 'sms',
              multi_factor_auth_method_created_at: phone_configuration_created_at.strftime('%s%L'),
              phone_configuration_id: phone_id,
              area_code: parsed_phone.area_code,
              country_code: parsed_phone.country,
              phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
              enabled_mfa_methods_count: 1,
              in_account_creation_flow: true,
              attempts: 1,
            )
          end

          it 'resets otp session data' do
            expect(subject.user_session[:unconfirmed_phone]).to be_nil
            expect(subject.user_session[:context]).to eq 'authentication'
          end

          it 'tracks the update event and notifies via email about number change' do
            expect(subject).to have_received(:create_user_event).with(:phone_changed)
            expect(subject).to have_received(:create_user_event).exactly(:once)

            expect_delivered_email_count(1)
            expect_delivered_email(
              to: [subject.current_user.email_addresses.first.email],
              subject: t('user_mailer.phone_added.subject'),
            )
          end
        end

        context 'user enters an invalid code' do
          before do
            stub_attempts_tracker
            expect(@attempts_api_tracker).to receive(:mfa_enrolled).with(
              success: false,
              mfa_device_type: 'phone',
              otp_delivery_method: 'sms',
              phone_number: parsed_phone.e164,
            )

            post(
              :create,
              params: {
                code: '999',
                otp_delivery_preference: 'sms',
              },
            )
          end

          it 'increments second_factor_attempts_count' do
            expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
          end

          it 'does not clear session data' do
            expect(subject.user_session[:unconfirmed_phone]).to eq('+1 (703) 555-5555')
          end

          it 'does not update user phone or phone_confirmed_at attributes' do
            first_configuration = MfaContext.new(subject.current_user).phone_configurations.first
            expect(first_configuration.phone).to eq('+1 202-555-1212')
            expect(first_configuration.confirmed_at).to eq(@previous_phone_confirmed_at)
          end

          it 'renders :show' do
            expect(response).to render_template(:show)
          end

          it 'displays error flash notice' do
            expect(flash[:error]).to eq t('two_factor_authentication.invalid_otp')
          end

          it 'tracks an event' do
            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication Setup',
              success: false,
              error_details: { code: { wrong_length: true, incorrect: true } },
              confirmation_for_add_phone: true,
              context: 'confirmation',
              multi_factor_auth_method: 'sms',
              phone_configuration_id: controller.current_user.default_phone_configuration.id,
              multi_factor_auth_method_created_at: controller.current_user
                .default_phone_configuration.created_at.strftime('%s%L'),
              area_code: parsed_phone.area_code,
              country_code: parsed_phone.country,
              phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
              enabled_mfa_methods_count: 1,
              in_account_creation_flow: false,
              attempts: 1,
            )
          end

          context 'user enters in valid code after invalid entry' do
            before do
              expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
              expect(@attempts_api_tracker).to receive(:mfa_enrolled).with(
                success: true,
                mfa_device_type: 'phone',
                otp_delivery_method: 'sms',
                phone_number: parsed_phone.e164,
              )
              post(
                :create,
                params: {
                  code: subject.current_user.direct_otp,
                  otp_delivery_preference: 'sms',
                },
              )
            end
            it 'resets second_factor_attempts_count' do
              expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
            end

            it 'tracks an event' do
              expect(@analytics).to have_logged_event(
                'Multi-Factor Authentication Setup',
                success: false,
                error_details: { code: { wrong_length: true, incorrect: true } },
                confirmation_for_add_phone: true,
                context: 'confirmation',
                multi_factor_auth_method: 'sms',
                phone_configuration_id: controller.current_user.default_phone_configuration.id,
                multi_factor_auth_method_created_at: controller.current_user
                  .default_phone_configuration.created_at.strftime('%s%L'),
                area_code: parsed_phone.area_code,
                country_code: parsed_phone.country,
                phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
                enabled_mfa_methods_count: 1,
                in_account_creation_flow: false,
                attempts: 1,
              )
            end
          end
        end

        context 'user does not include a code parameter' do
          it 'fails and increments attempts count' do
            post :create, params: { otp_delivery_preference: 'sms' }
            expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
          end
        end
      end

      context 'when user does not have an existing phone number' do
        before do
          MfaContext.new(controller.current_user).phone_configurations.clear
          controller.current_user.create_direct_otp
        end

        context 'when given valid code' do
          subject(:response) do
            post(
              :create,
              params: {
                code: controller.current_user.direct_otp,
                otp_delivery_preference: 'sms',
              },
            )
          end

          it 'redirects to profile page' do
            expect(response).to redirect_to(account_path)
          end

          it 'tracks the confirmation event' do
            parsed_phone = Phonelib.parse('+1 (703) 555-5555')
            expect(@attempts_api_tracker).to receive(:mfa_enrolled).with(
              success: true,
              mfa_device_type: 'phone',
              otp_delivery_method: 'sms',
              phone_number: parsed_phone.e164,
            )

            response

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication Setup',
              success: true,
              context: 'confirmation',
              multi_factor_auth_method: 'sms',
              confirmation_for_add_phone: false,
              area_code: parsed_phone.area_code,
              country_code: parsed_phone.country,
              phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
              enabled_mfa_methods_count: 0,
              in_account_creation_flow: false,
              attempts: 1,
            )

            expect(controller).to have_received(:create_user_event).with(:phone_confirmed)
            expect(controller).to have_received(:create_user_event).exactly(:once)
          end

          it 'annotates with passed 2fa and resets a recaptcha assessment' do
            assessment_id = 'projects/project-id/assessments/assessment-id'
            recaptcha_annotation = {
              assessment_id:,
              reason: RecaptchaAnnotator::AnnotationReasons::PASSED_TWO_FACTOR,
            }

            controller.user_session[:phone_recaptcha_assessment_id] = assessment_id

            expect(RecaptchaAnnotator).to receive(:annotate)
              .with(**recaptcha_annotation)
              .and_return(recaptcha_annotation)

            expect { response }
              .to change { controller.user_session[:phone_recaptcha_assessment_id] }
              .from(assessment_id).to(nil)

            expect(@analytics).to have_logged_event(
              'Multi-Factor Authentication: Added phone',
              hash_including(recaptcha_annotation:),
            )
          end

          it 'resets context to authentication' do
            response

            expect(controller.user_session[:context]).to eq 'authentication'
          end
        end

        describe 'multiple MFA handling' do
          let(:mfa_selections) { ['sms', 'backup_code'] }
          before do
            subject.user_session[:mfa_selections] = mfa_selections

            post(
              :create,
              params: {
                code: subject.current_user.direct_otp,
                otp_delivery_preference: 'sms',
              },
            )
          end

          context 'multiple MFA options selected' do
            it 'redirects to next mfa method with backup code next' do
              expect(response).to redirect_to(backup_code_setup_url)
            end
          end

          context 'one MFA option selected' do
            let(:mfa_selections) { ['sms'] }

            it 'redirects to auth_confirmation page' do
              expect(response).to redirect_to(auth_method_confirmation_url)
            end
          end
        end
      end

      context 'with remember_device in the params' do
        it 'saves an encrypted cookie' do
          freeze_time do
            expect(cookies.encrypted[:remember_device]).to eq nil
            post(
              :create,
              params: {
                code: subject.current_user.direct_otp,
                otp_delivery_preference: 'sms',
                remember_device: '1',
              },
            )

            remember_device_cookie = RememberDeviceCookie.from_json(
              cookies.encrypted[:remember_device],
            )
            expiration_interval = IdentityConfig.store.remember_device_expiration_hours_aal_1.hours
            expect(
              remember_device_cookie.valid_for_user?(
                user: subject.current_user,
                expiration_interval: expiration_interval,
              ),
            ).to eq true
          end
        end
      end

      context 'without remember_device in the params' do
        it 'does not save an encrypted cookie' do
          post(
            :create,
            params: {
              code: subject.current_user.direct_otp,
              otp_delivery_preference: 'sms',
            },
          )

          expect(cookies[:remember_device]).to be_nil
        end
      end
    end
  end
end
