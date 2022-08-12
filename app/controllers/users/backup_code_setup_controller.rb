module Users
  class BackupCodeSetupController < ApplicationController
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :ensure_backup_codes_in_session, only: %i[continue refreshed]
    before_action :set_backup_code_setup_presenter
    before_action :apply_secure_headers_override
    before_action :authorize_backup_code_disable, only: [:delete]

    helper_method :in_multi_mfa_selection_flow?

    def index
      track_backup_codes_confirmation_setup_visit
    end

    def create
      generate_codes
      result = BackupCodeSetupForm.new(current_user).submit
      analytics.backup_code_setup_visit(**result.to_h)
      irs_attempts_api_tracker.mfa_enroll_backup_code(success: result.success?)

      save_backup_codes
      track_backup_codes_created
    end

    def edit; end

    def continue
      flash[:success] = t('notices.backup_codes_configured')
      analytics.multi_factor_auth_setup(**analytics_properties)
      redirect_to next_setup_path || after_mfa_setup_path
    end

    def confirm_delete; end

    def refreshed
      @codes = user_session[:backup_codes]
      render 'create'
    end

    def delete
      current_user.backup_code_configurations.destroy_all
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
      flash[:success] = t('notices.backup_codes_deleted')
      revoke_remember_device(current_user)
      redirect_to account_two_factor_authentication_path
    end

    private

    def track_backup_codes_created
      analytics.backup_code_created(
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
      )
      Funnel::Registration::AddMfa.call(current_user.id, 'backup_codes', analytics)
    end

    def mfa_user
      @mfa_user ||= MfaContext.new(current_user)
    end

    def track_backup_codes_confirmation_setup_visit
      analytics.multi_factor_auth_enter_backup_code_confirmation_visit(
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
      )
    end

    def ensure_backup_codes_in_session
      redirect_to backup_code_setup_url unless user_session[:backup_codes]
    end

    def generate_codes
      revoke_remember_device(current_user)
      @codes = generator.generate
      user_session[:backup_codes] = @codes
    end

    def set_backup_code_setup_presenter
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

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def save_backup_codes
      mark_user_as_fully_authenticated
      generator.save(user_session[:backup_codes])
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
      create_user_event(:backup_codes_added)
    end

    def generator
      @generator ||= BackupCodeGenerator.new(current_user)
    end

    def authorize_backup_code_disable
      return if MfaPolicy.new(current_user).multiple_non_restricted_factors_enabled?
      redirect_to account_two_factor_authentication_path
    end

    def analytics_properties
      {
        success: true,
        multi_factor_auth_method: 'backup_codes',
        in_multi_mfa_selection_flow: in_multi_mfa_selection_flow?,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      }
    end
  end
end
