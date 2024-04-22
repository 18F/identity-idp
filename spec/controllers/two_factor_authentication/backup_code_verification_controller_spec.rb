require 'rails_helper'

RSpec.describe TwoFactorAuthentication::BackupCodeVerificationController do
  let(:user) { create(:user) }
  let(:backup_codes) do
    BackupCodeGenerator.new(user).create
  end
  let(:payload) { { backup_code_verification_form: { backup_code: backup_codes.first } } }

  describe '#show' do
    it 'tracks the page visit' do
      stub_sign_in_before_2fa(user)
      stub_analytics
      analytics_hash = { context: 'authentication' }

      expect(@analytics).to receive(:track_event).
        with('Multi-Factor Authentication: enter backup code visited', analytics_hash)

      get :show
    end
  end

  describe '#create' do
    context 'when the user enters a valid backup code' do
      it 'tracks the valid authentication event' do
        freeze_time do
          sign_in_before_2fa(user)
          stub_analytics
          stub_attempts_tracker
          analytics_hash = {
            success: true,
            errors: {},
            multi_factor_auth_method: 'backup_code',
            multi_factor_auth_method_created_at: Time.zone.now.strftime('%s%L'),
            new_device: nil,
          }

          expect(@analytics).to receive(:track_mfa_submit_event).
            with(analytics_hash)

          expect(@irs_attempts_api_tracker).to receive(:track_event).
            with(:mfa_login_backup_code, success: true)

          expect(controller).to receive(:handle_valid_verification_for_authentication_context).
            with(auth_method: TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE).
            and_call_original

          post :create, params: payload

          expect(subject.user_session[:auth_events]).to eq(
            [
              auth_method: TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE,
              at: Time.zone.now,
            ],
          )
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
        end
      end

      context 'with remember_device in the params' do
        it 'saves an encrypted cookie' do
          stub_sign_in_before_2fa(user)

          freeze_time do
            expect(cookies.encrypted[:remember_device]).to eq nil
            post(
              :create,
              params: {
                backup_code_verification_form: {
                  backup_code: backup_codes.first,
                  remember_device: '1',
                },
              },
            )

            remember_device_cookie = RememberDeviceCookie.from_json(
              cookies.encrypted[:remember_device],
            )
            expiration_interval = IdentityConfig.store.remember_device_expiration_hours_aal_1.hours
            expect(
              remember_device_cookie.valid_for_user?(
                user: user,
                expiration_interval: expiration_interval,
              ),
            ).to eq true
          end
        end
      end

      it 'tracks the valid authentication event when there are exisitng codes' do
        freeze_time do
          stub_sign_in_before_2fa(user)
          stub_analytics
          stub_attempts_tracker

          expect(@analytics).to receive(:track_mfa_submit_event).
            with({
              success: true,
              errors: {},
              multi_factor_auth_method: 'backup_code',
              multi_factor_auth_method_created_at: Time.zone.now.strftime('%s%L'),
              new_device: nil,
            })

          expect(@irs_attempts_api_tracker).to receive(:track_event).
            with(:mfa_login_backup_code, success: true)

          expect(@analytics).to receive(:track_event).
            with('User marked authenticated', authentication_type: :valid_2fa)

          post :create, params: payload
        end
      end
    end

    context 'with new device session value' do
      it 'tracks new device value' do
        freeze_time do
          sign_in_before_2fa(user)
          subject.user_session[:new_device] = false
          stub_analytics
          stub_attempts_tracker
          analytics_hash = {
            success: true,
            errors: {},
            multi_factor_auth_method: 'backup_code',
            multi_factor_auth_method_created_at: Time.zone.now.strftime('%s%L'),
            new_device: false,
          }

          expect(@analytics).to receive(:track_mfa_submit_event).
            with(analytics_hash)

          expect(@irs_attempts_api_tracker).to receive(:track_event).
            with(:mfa_login_backup_code, success: true)

          post :create, params: payload

          expect(subject.user_session[:auth_events]).to eq(
            [
              auth_method: TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE,
              at: Time.zone.now,
            ],
          )
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
        end
      end
    end

    context 'when the backup code field is empty' do
      let(:backup_code) { { backup_code: '' } }
      let(:payload) { { backup_code_verification_form: backup_code } }

      before do
        stub_sign_in_before_2fa(create(:user, :with_phone))
      end

      it 'renders the show page' do
        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_login_backup_code, success: false)
        post :create, params: payload
        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_backup_code')
      end
    end

    context 'when the user enters an invalid backup code' do
      render_views
      let(:user) { create(:user, :with_phone) }
      let(:payload) { { backup_code_verification_form: { backup_code: 'A' } } }
      before do
        stub_sign_in_before_2fa(user)
      end

      it 're-renders the backup code entry screen' do
        stub_attempts_tracker
        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_login_backup_code, success: false)
        post :create, params: payload

        expect(response).to render_template(:show)
        expect(flash[:error]).to eq t('two_factor_authentication.invalid_backup_code')
        expect(subject.user_session[:auth_events]).to eq nil
        expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq true
      end

      it 'tracks the max attempts event' do
        user.second_factor_attempts_count =
          IdentityConfig.store.login_otp_confirmation_max_attempts - 1
        user.save
        properties = {
          success: false,
          errors: {},
          multi_factor_auth_method: 'backup_code',
          multi_factor_auth_method_created_at: nil,
          new_device: nil,
        }

        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(properties)

        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_login_backup_code, success: false)

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: max attempts reached')

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_rate_limited).
          with(mfa_device_type: 'backup_code')

        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        post :create, params: payload
      end

      it 'records unsuccessful 2fa event' do
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        post :create, params: payload
      end
    end
  end
end
