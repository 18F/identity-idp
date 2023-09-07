module Users
  class TotpSetupController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include MfaSetupConcern
    include SecureHeadersConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_totp_setup_presenter
    before_action :apply_secure_headers_override
    before_action :cap_auth_app_count, only: %i[new confirm]
    before_action :confirm_recently_authenticated_2fa

    helper_method :in_multi_mfa_selection_flow?

    def new
      store_totp_secret_in_session
      track_event

      @code = new_totp_secret
      @qrcode = current_user.qrcode(new_totp_secret)
    end

    def confirm
      result = totp_setup_form.submit

      properties = result.to_h.merge(analytics_properties)
      analytics.multi_factor_auth_setup(**properties)

      irs_attempts_api_tracker.mfa_enroll_totp(
        success: result.success?,
      )

      if result.success?
        process_valid_code
      else
        process_invalid_code
      end
    end

    def disable
      if MfaPolicy.new(current_user).multiple_factors_enabled?
        process_successful_disable
      else
        redirect_to account_two_factor_authentication_path
      end
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

    def track_event
      mfa_user = MfaContext.new(current_user)
      analytics.totp_setup_visit(
        user_signed_up: MfaPolicy.new(current_user).two_factor_enabled?,
        totp_secret_present: new_totp_secret.present?,
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
        in_account_creation_flow: in_account_creation_flow?,
      )
    end

    def store_totp_secret_in_session
      user_session[:new_totp_secret] = current_user.generate_totp_secret if new_totp_secret.nil?
    end

    def process_valid_code
      create_events
      handle_valid_verification_for_confirmation_context(
        auth_method: TwoFactorAuthenticatable::AuthMethod::TOTP,
      )
      handle_remember_device_preference(params[:remember_device])
      flash[:success] = t('notices.totp_configured')
      user_session.delete(:new_totp_secret)
      user_session.delete(:in_account_creation_flow)
      redirect_to next_setup_path || after_mfa_setup_path
    end

    def create_events
      create_user_event(:authenticator_enabled)
      mfa_user = MfaContext.new(current_user)
      analytics.multi_factor_auth_added_totp(
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
        in_account_creation_flow: in_account_creation_flow?,
      )
      Funnel::Registration::AddMfa.call(current_user.id, 'auth_app', analytics)
    end

    def process_successful_disable
      analytics.totp_user_disabled
      create_user_event(:authenticator_disabled)
      revoke_remember_device(current_user)
      revoke_otp_secret_key
      flash[:success] = t('notices.totp_disabled')
      redirect_to account_two_factor_authentication_path
    end

    def revoke_otp_secret_key
      Db::AuthAppConfiguration.delete(current_user, params[:id].to_i)
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
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

    def in_account_creation_flow?
      user_session[:in_account_creation_flow] || false
    end

    def analytics_properties
      {
        in_account_creation_flow: in_account_creation_flow?,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
      }
    end
  end
end
