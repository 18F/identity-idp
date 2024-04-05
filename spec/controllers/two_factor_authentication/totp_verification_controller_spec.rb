require 'rails_helper'

RSpec.describe TwoFactorAuthentication::TotpVerificationController do
  before do
    stub_analytics
    stub_attempts_tracker
  end

  describe '#create' do
    context 'when the user enters a valid TOTP' do
      before do
        sign_in_before_2fa
        @secret = subject.current_user.generate_totp_secret
        user = subject.current_user
        Db::AuthAppConfiguration.create(user, @secret, nil, 'foo')
      end

      it 'redirects to the profile and sets auth_method' do
        cfg = controller.current_user.auth_app_configurations.first
        expect(Db::AuthAppConfiguration).to receive(:authenticate).and_return(cfg)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0

        freeze_time do
          post :create, params: { code: generate_totp_code(@secret) }

          expect(response).to redirect_to account_path
          expect(subject.user_session[:auth_events]).to eq(
            [
              auth_method: TwoFactorAuthenticatable::AuthMethod::TOTP,
              at: Time.zone.now,
            ],
          )
          expect(subject.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq false
        end
      end

      it 'resets the second_factor_attempts_count' do
        UpdateUser.new(
          user: subject.current_user,
          attributes: { second_factor_attempts_count: 1 },
        ).call

        post :create, params: { code: generate_totp_code(@secret) }

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        cfg = controller.current_user.auth_app_configurations.first

        attributes = {
          success: true,
          errors: {},
          multi_factor_auth_method: 'totp',
          multi_factor_auth_method_created_at: cfg.created_at.strftime('%s%L'),
          new_device: nil,
          auth_app_configuration_id: controller.current_user.auth_app_configurations.first.id,
        }
        expect(@analytics).to receive(:track_mfa_submit_event).
          with(attributes)
        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa)
        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_login_totp, success: true)
        expect(controller).to receive(:handle_valid_verification_for_authentication_context).
          with(auth_method: TwoFactorAuthenticatable::AuthMethod::TOTP).
          and_call_original

        post :create, params: { code: generate_totp_code(@secret) }
      end

      context 'with new device session value' do
        before do
          subject.user_session[:new_device] = false
        end
        it 'tracks new device value' do
          cfg = controller.current_user.auth_app_configurations.first

          attributes = {
            success: true,
            errors: {},
            multi_factor_auth_method: 'totp',
            multi_factor_auth_method_created_at: cfg.created_at.strftime('%s%L'),
            new_device: false,
            auth_app_configuration_id: controller.current_user.auth_app_configurations.first.id,
          }
          expect(@analytics).to receive(:track_mfa_submit_event).
            with(attributes)

          post :create, params: { code: generate_totp_code(@secret) }
        end
      end
    end

    context 'with multiple TOTP configurations' do
      it 'allows using codes generated from any registered TOTP configuration' do
        user = create(:user, :fully_registered)
        app1 = Db::AuthAppConfiguration.create(user, user.generate_totp_secret, nil, 'foo')
        app2 = Db::AuthAppConfiguration.create(user, user.generate_totp_secret, nil, 'bar')

        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', authentication_type: :valid_2fa).twice

        sign_in_as_user(user)
        post :create, params: { code: generate_totp_code(app1.otp_secret_key) }
        expect(response).to redirect_to account_url

        sign_out(user)

        sign_in_as_user(user)
        post :create, params: { code: generate_totp_code(app2.otp_secret_key) }
        expect(response).to redirect_to account_url
      end
    end

    context 'when the user enters an invalid TOTP' do
      subject(:response) { post :create, params: { code: 'abc' } }

      before do
        sign_in_before_2fa
        user = controller.current_user
        @secret = user.generate_totp_secret
        Db::AuthAppConfiguration.create(user, @secret, nil, 'foo')
      end

      it 'increments second_factor_attempts_count' do
        response

        expect(controller.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 're-renders the TOTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        response

        expect(flash[:error]).to eq t('two_factor_authentication.invalid_otp')
      end

      it 'does not set auth_method and still requires 2FA' do
        response

        expect(controller.user_session[:auth_events]).to eq nil
        expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq true
      end

      it 'records unsuccessful 2fa event' do
        expect(controller).to receive(:create_user_event).with(:sign_in_unsuccessful_2fa)

        response
      end
    end

    context 'when the user has reached the max number of TOTP attempts' do
      it 'tracks the event' do
        user = create(
          :user,
          :fully_registered,
          second_factor_attempts_count:
            IdentityConfig.store.login_otp_confirmation_max_attempts - 1,
        )
        sign_in_before_2fa(user)
        @secret = user.generate_totp_secret
        Db::AuthAppConfiguration.create(user, @secret, nil, 'foo')

        attributes = {
          success: false,
          errors: {},
          multi_factor_auth_method: 'totp',
          multi_factor_auth_method_created_at: nil,
          new_device: nil,
          auth_app_configuration_id: nil,
        }

        expect(@analytics).to receive(:track_mfa_submit_event).
          with(attributes)
        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: max attempts reached')
        expect(@irs_attempts_api_tracker).to receive(:track_event).
          with(:mfa_login_totp, success: false)

        expect(@irs_attempts_api_tracker).to receive(:mfa_login_rate_limited).
          with(mfa_device_type: 'totp')

        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::MfaLimitAccountLockedEvent.new(user: subject.current_user))

        post :create, params: { code: '12345' }
      end
    end

    context 'when the user lockout period expires' do
      before do
        lockout_period = IdentityConfig.store.lockout_period_in_minutes.minutes
        user = create(
          :user,
          :fully_registered,
          second_factor_locked_at: Time.zone.now - lockout_period - 1.second,
          second_factor_attempts_count: 3,
        )
        sign_in_before_2fa(user)
        @secret = subject.current_user.generate_totp_secret
        user = subject.current_user
        Db::AuthAppConfiguration.create(user, @secret, nil, 'foo')
      end

      describe 'when user submits an invalid TOTP' do
        before do
          post :create, params: { code: '12345' }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits an invalid form' do
        it 'fails with empty code' do
          expect { post :create, params: { code: '' } }.
            to raise_error(ActionController::ParameterMissing)
        end

        it 'fails with no code parameter' do
          expect { post :create, params: { fake_code: 'abc123' } }.
            to raise_error(ActionController::ParameterMissing)
        end
      end

      describe 'when user submits a valid TOTP' do
        before do
          post :create, params: { code: generate_totp_code(@secret) }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end

    context 'when the user does not have an authenticator app enabled' do
      it 'redirects to user_two_factor_authentication_path' do
        stub_sign_in_before_2fa
        post :create, params: { code: '123456' }

        expect(response).to redirect_to user_two_factor_authentication_path
      end
    end
  end

  describe '#show' do
    let(:user) { build(:user) }
    before { stub_sign_in_before_2fa(user) }

    context 'when the user does not have an authenticator app enabled' do
      it 'redirects to user_two_factor_authentication_path' do
        get :show

        expect(response).to redirect_to user_two_factor_authentication_path
      end
    end

    context 'when the user has an authenticator app enabled' do
      let(:user) { build(:user, :with_authentication_app) }

      it 'logs the visited event' do
        get :show

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication: enter TOTP visited',
          { context: 'authentication' },
        )
      end

      it 'sets view assigns' do
        get :show

        expect(assigns(:presenter)).to be_present
        expect(assigns(:code)).not_to be_present
      end

      context 'when FeatureManagement.prefill_otp_codes? is true' do
        before do
          allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
        end

        it 'sets view assigns' do
          get :show

          expect(assigns(:presenter)).to be_present
          expect(assigns(:code)).to be_present
        end
      end
    end
  end
end
