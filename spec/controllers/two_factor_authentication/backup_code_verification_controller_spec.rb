require 'rails_helper'

RSpec.describe TwoFactorAuthentication::BackupCodeVerificationController do
  let(:user) { create(:user) }
  let(:backup_codes) do
    BackupCodeGenerator.new(user).delete_and_regenerate
  end
  let(:payload) { { backup_code_verification_form: { backup_code: backup_codes.first } } }

  describe '#show' do
    it 'tracks the page visit' do
      stub_sign_in_before_2fa(user)
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event(
        'Multi-Factor Authentication: enter backup code visited',
        context: 'authentication',
      )
    end
  end

  describe '#create' do
    context 'when the user enters a valid backup code' do
      it 'tracks the valid authentication event' do
        freeze_time do
          sign_in_before_2fa(user)
          stub_analytics

          expect(controller).to receive(:handle_valid_verification_for_authentication_context)
            .with(auth_method: TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE)
            .and_call_original

          post :create, params: payload

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: true,
            multi_factor_auth_method: 'backup_code',
            multi_factor_auth_method_created_at: Time.zone.now.strftime('%s%L'),
            enabled_mfa_methods_count: 1,
            new_device: true,
            attempts: 1,
          )

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

          post :create, params: payload

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication',
            success: true,
            multi_factor_auth_method: 'backup_code',
            multi_factor_auth_method_created_at: Time.zone.now.strftime('%s%L'),
            enabled_mfa_methods_count: 1,
            new_device: true,
            attempts: 1,
          )
          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            authentication_type: :valid_2fa,
          )
        end
      end
    end

    context 'with existing device' do
      before do
        allow(controller).to receive(:new_device?).and_return(false)
      end

      it 'tracks new device value' do
        stub_analytics
        stub_sign_in_before_2fa(user)

        post :create, params: payload

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication',
          hash_including(new_device: false),
        )
      end
    end

    context 'when the backup code field is empty' do
      let(:backup_code) { { backup_code: '' } }
      let(:payload) { { backup_code_verification_form: backup_code } }

      before do
        stub_sign_in_before_2fa(create(:user, :with_phone))
      end

      it 'renders the show page' do
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

        stub_analytics

        expect(PushNotification::HttpPush).to receive(:deliver)
          .with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        post :create, params: payload

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication',
          success: false,
          error_details: { backup_code: { invalid: true } },
          multi_factor_auth_method: 'backup_code',
          enabled_mfa_methods_count: 1,
          new_device: true,
          attempts: 1,
        )
        expect(@analytics).to have_logged_event('Multi-Factor Authentication: max attempts reached')
      end

      it 'records unsuccessful 2fa event' do
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        post :create, params: payload
      end
    end
  end
end
