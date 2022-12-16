require 'rails_helper'

describe TwoFactorAuthentication::OtpVerificationController do
  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      before do
        sign_in_before_2fa
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
          controller.user_session[:phone_id] = 0

          get :show, params: { otp_delivery_preference: 'sms' }
          expect(response).to redirect_to new_user_session_path
        end
      end
    end

    it 'tracks the page visit and context' do
      user = build_stubbed(:user, :with_phone, with: { phone: '+1 (703) 555-0100' })
      stub_sign_in_before_2fa(user)
      parsed_phone = Phonelib.parse(subject.current_user.default_phone_configuration.phone)

      stub_analytics
      analytics_hash = {
        context: 'authentication',
        multi_factor_auth_method: 'sms',
        confirmation_for_add_phone: false,
        phone_configuration_id: subject.current_user.default_phone_configuration.id,
        area_code: parsed_phone.area_code,
        country_code: parsed_phone.country,
        phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        enabled_mfa_methods_count: 1,
        in_multi_mfa_selection_flow: false,
      }

      expect(@analytics).to receive(:track_event).
        with('Multi-Factor Authentication: enter OTP visited', analytics_hash)

      get :show, params: { otp_delivery_preference: 'sms' }
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
  end

  describe '#create' do
    let(:parsed_phone) { Phonelib.parse(subject.current_user.default_phone_configuration.phone) }
    context 'when the user enters an invalid OTP during authentication context' do
      before do
        sign_in_before_2fa

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0

        properties = {
          success: false,
          error_details: { code: [:incorrect_length, :incorrect] },
          confirmation_for_add_phone: false,
          context: 'authentication',
          multi_factor_auth_method: 'sms',
          phone_configuration_id: subject.current_user.default_phone_configuration.id,
          area_code: parsed_phone.area_code,
          country_code: parsed_phone.country,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
          enabled_mfa_methods_count: 1,
          in_multi_mfa_selection_flow: false,
        }

        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties)

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_submitted).
          with({ reauthentication: false, success: false })

        post :create, params:
        { code: '12345',
          otp_delivery_preference: 'sms' }
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'redirects to the OTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_otp')
      end
    end

    context 'when the user enters an invalid OTP during reauthentication context' do
      it 'increments second_factor_attempts_count' do
        sign_in_before_2fa
        controller.user_session[:context] = 'reauthentication'

        post :create, params: { code: '12345', otp_delivery_preference: 'sms' }

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end
    end

    context 'when the user has reached the max number of OTP attempts' do
      it 'tracks the event' do
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        sign_in_before_2fa

        properties = {
          success: false,
          error_details: { code: [:incorrect_length, :incorrect] },
          confirmation_for_add_phone: false,
          context: 'authentication',
          multi_factor_auth_method: 'sms',
          phone_configuration_id: subject.current_user.default_phone_configuration.id,
          area_code: parsed_phone.area_code,
          country_code: parsed_phone.country,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
          enabled_mfa_methods_count: 1,
          in_multi_mfa_selection_flow: false,
        }

        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties)

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: max attempts reached')
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_submitted).
          with({ reauthentication: false, success: false })

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_rate_limited).
          with(mfa_device_type: 'otp')

        post :create, params:
        { code: '12345',
          otp_delivery_preference: 'sms' }
      end
    end

    context 'when the user enters a valid OTP' do
      before do
        sign_in_before_2fa
        form = OtpVerificationForm.new(subject.current_user, nil)
        result = FormResponse.new(success: true, serialize_error_details_only: {})
        expect(form).to receive(:submit).and_return(result)
        expect(subject).to receive(:otp_verification_form).and_return(form)
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
        properties = {
          success: true,
          confirmation_for_add_phone: false,
          context: 'authentication',
          multi_factor_auth_method: 'sms',
          phone_configuration_id: subject.current_user.default_phone_configuration.id,
          area_code: parsed_phone.area_code,
          country_code: parsed_phone.country,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
          enabled_mfa_methods_count: 1,
          in_multi_mfa_selection_flow: false,
        }

        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties)
        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_submitted).
          with(reauthentication: false, success: true)

        post :create, params: {
          code: subject.current_user.reload.direct_otp,
          otp_delivery_preference: 'sms',
        }
      end

      it 'tracks the attempt event with reauthentication parameter true' do
        stub_attempts_tracker

        subject.user_session[:context] = 'reauthentication'

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_submitted).
          with(reauthentication: true, success: true)

        post :create, params: {
          code: subject.current_user.reload.direct_otp,
          otp_delivery_preference: 'sms',
        }
      end

      context 'with remember_device in the params' do
        it 'saves an encrypted cookie' do
          remember_device_cookie = instance_double(RememberDeviceCookie)
          allow(remember_device_cookie).to receive(:to_json).and_return('asdf1234')
          allow(RememberDeviceCookie).to receive(:new).and_return(remember_device_cookie)

          post(
            :create,
            params: {
              code: subject.current_user.direct_otp,
              otp_delivery_preference: 'sms',
              remember_device: '1',
            },
          )

          expect(cookies.encrypted[:remember_device]).to eq('asdf1234')
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
        sign_in_before_2fa
        lockout_period = IdentityConfig.store.lockout_period_in_minutes.minutes
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - lockout_period - 1.second,
          second_factor_attempts_count: 3,
        )
      end

      describe 'when user submits an invalid OTP' do
        before do
          stub_attempts_tracker

          expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_submitted).
            with({ reauthentication: false, success: false })
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
          stub_attempts_tracker

          expect(@irs_attempts_api_tracker).to receive(:mfa_login_phone_otp_submitted).
            with({ reauthentication: false, success: true })
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
      before do
        sign_in_as_user
        subject.user_session[:unconfirmed_phone] = '+1 (703) 555-5555'
        subject.user_session[:context] = 'confirmation'

        @previous_phone_confirmed_at =
          MfaContext.new(subject.current_user).phone_configurations.first&.confirmed_at

        subject.current_user.create_direct_otp

        stub_analytics
        stub_attempts_tracker

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        @mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)

        subject.current_user.email_addresses.each do |email_address|
          allow(UserMailer).to receive(:phone_added).
            with(subject.current_user, email_address, disavowal_token: instance_of(String)).
            and_return(@mailer)
        end
        @previous_phone = MfaContext.new(subject.current_user).phone_configurations.first&.phone
      end

      context 'user has an existing phone number' do
        context 'user enters a valid code' do
          before do
            phone_configuration = MfaContext.new(subject.current_user).phone_configurations.last
            phone_id = phone_configuration.id
            parsed_phone = Phonelib.parse(phone_configuration.phone)

            properties = {
              success: true,
              errors: nil,
              confirmation_for_add_phone: true,
              context: 'confirmation',
              multi_factor_auth_method: 'sms',
              phone_configuration_id: phone_id,
              area_code: parsed_phone.area_code,
              country_code: parsed_phone.country,
              phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
              enabled_mfa_methods_count: 1,
              in_multi_mfa_selection_flow: false,
            }

            expect(@analytics).to receive(:track_event).
              with('Multi-Factor Authentication Setup', properties)
            controller.user_session[:phone_id] = phone_id

            expect(@irs_attempts_api_tracker).to receive(:mfa_enroll_phone_otp_submitted).
              with(success: true)

            post(
              :create,
              params: {
                code: subject.current_user.direct_otp,
                otp_delivery_preference: 'sms',
              },
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
            expect(@irs_attempts_api_tracker).to receive(:mfa_enroll_phone_otp_submitted).
              with(success: false)

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
            properties = {
              success: false,
              errors: nil,
              error_details: { code: [:incorrect_length, :incorrect] },
              confirmation_for_add_phone: true,
              context: 'confirmation',
              multi_factor_auth_method: 'sms',
              phone_configuration_id: subject.current_user.default_phone_configuration.id,
              area_code: parsed_phone.area_code,
              country_code: parsed_phone.country,
              phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
              enabled_mfa_methods_count: 1,
              in_multi_mfa_selection_flow: false,
            }

            expect(@analytics).to have_received(:track_event).
              with('Multi-Factor Authentication Setup', properties)
          end

          context 'user enters in valid code after invalid entry' do
            before do
              expect(@irs_attempts_api_tracker).to receive(:mfa_enroll_phone_otp_submitted).
                with(success: true)
              expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
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
          end

          context 'user has exceeded the maximum number of attempts' do
            it 'tracks the attempt event' do
              allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
              sign_in_before_2fa

              stub_attempts_tracker
              expect(@irs_attempts_api_tracker).to receive(:mfa_enroll_rate_limited).
                with(mfa_device_type: 'otp')

              post :create, params: { code: '12345', otp_delivery_preference: 'sms' }
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
          MfaContext.new(subject.current_user).phone_configurations.clear
          subject.current_user.create_direct_otp
        end

        context 'when given valid code' do
          before do
            post(
              :create,
              params: {
                code: subject.current_user.direct_otp,
                otp_delivery_preference: 'sms',
              },
            )
          end

          it 'redirects to profile page' do
            expect(response).to redirect_to(account_path)
          end

          it 'tracks the confirmation event' do
            parsed_phone = Phonelib.parse('+1 (703) 555-5555')
            properties = {
              success: true,
              errors: nil,
              context: 'confirmation',
              multi_factor_auth_method: 'sms',
              confirmation_for_add_phone: false,
              phone_configuration_id: nil,
              area_code: parsed_phone.area_code,
              country_code: parsed_phone.country,
              phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
              enabled_mfa_methods_count: 0,
              in_multi_mfa_selection_flow: false,
            }

            expect(@analytics).to have_received(:track_event).
              with('Multi-Factor Authentication Setup', properties)

            expect(subject).to have_received(:create_user_event).with(:phone_confirmed)
            expect(subject).to have_received(:create_user_event).exactly(:once)
          end

          it 'resets context to authentication' do
            expect(subject.user_session[:context]).to eq 'authentication'
          end
        end

        context 'Feature flag #select_multiple_mfa_options is true' do
          let(:mfa_selections) { ['sms', 'backup_code'] }
          before do
            subject.user_session[:mfa_selections] = mfa_selections
            allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true

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
          remember_device_cookie = instance_double(RememberDeviceCookie)
          allow(remember_device_cookie).to receive(:to_json).and_return('asdf1234')
          allow(RememberDeviceCookie).to receive(:new).and_return(remember_device_cookie)

          post(
            :create,
            params: {
              code: subject.current_user.direct_otp,
              otp_delivery_preference: 'sms',
              remember_device: '1',
            },
          )

          expect(cookies.encrypted[:remember_device]).to eq('asdf1234')
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
