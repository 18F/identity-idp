module Users
  class TotpSetupController < ApplicationController
    include RememberDeviceConcern
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_totp_setup_presenter
    before_action :apply_secure_headers_override
    before_action :cap_auth_app_count, only: %i[new confirm]

    def new
      store_totp_secret_in_session
      track_event

      @code = new_totp_secret
      @qrcode = current_user.decorate.qrcode(new_totp_secret)
    end

    def confirm
      result = totp_setup_form.submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, result.to_h)

      if result.success?
        process_valid_code
      else
        process_invalid_code
      end
    end

    def disable
      process_successful_disable if MfaPolicy.new(current_user).multiple_factors_enabled?

      redirect_to account_two_factor_authentication_path
    end

    private

    def totp_setup_form
      @totp_setup_form ||= TotpSetupForm.new(
        current_user,
        new_totp_secret,
        params[:code].to_s.strip,
        params[:name].to_s.strip,
      )
    end

    def set_totp_setup_presenter
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def user_opted_remember_device_cookie
      cookies.encrypted[:user_opted_remember_device_preference]
    end

    def track_event
      properties = {
        user_signed_up: MfaPolicy.new(current_user).two_factor_enabled?,
        totp_secret_present: new_totp_secret.present?,
      }
      analytics.track_event(Analytics::TOTP_SETUP_VISIT, properties)
    end

    def store_totp_secret_in_session
      user_session[:new_totp_secret] = current_user.generate_totp_secret if new_totp_secret.nil?
    end

    def process_valid_code
      create_events
      mark_user_as_fully_authenticated
      handle_remember_device
      flash[:success] = t('notices.totp_configured')
      user_session.delete(:new_totp_secret)
      redirect_to user_next_authentication_setup_path!(after_mfa_setup_path)
    end

    def handle_remember_device
      save_user_opted_remember_device_pref
      save_remember_device_preference
    end

    def create_events
      create_user_event(:authenticator_enabled)
      Funnel::Registration::AddMfa.call(current_user.id, 'auth_app')
    end

    def process_successful_disable
      analytics.track_event(Analytics::TOTP_USER_DISABLED)
      create_user_event(:authenticator_disabled)
      revoke_remember_device(current_user)
      revoke_otp_secret_key
      flash[:success] = t('notices.totp_disabled')
    end

    def revoke_otp_secret_key
      Db::AuthAppConfiguration.delete(current_user, params[:id].to_i)
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def process_invalid_code
      flash[:error] = if totp_setup_form.name_taken
                        t('errors.piv_cac_setup.unique_name')
                      else
                        t('errors.invalid_totp')
                      end
      redirect_to authenticator_setup_url
    end

    def new_totp_secret
      user_session[:new_totp_secret]
    end

    def cap_auth_app_count
      return unless IdentityConfig.store.max_auth_apps_per_account <= current_auth_app_count
      redirect_to account_two_factor_authentication_path
    end

    def current_auth_app_count
      current_user.auth_app_configurations.count
    end
  end
end
