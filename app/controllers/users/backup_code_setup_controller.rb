module Users
  class BackupCodeSetupController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include MfaSetupConcern
    include SecureHeadersConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :ensure_backup_codes_in_session, only: %i[continue refreshed]
    before_action :set_backup_code_setup_presenter
    before_action :apply_secure_headers_override
    before_action :authorize_backup_code_disable, only: [:delete]
    before_action :confirm_recently_authenticated_2fa, except: [:reminder, :continue]
    before_action :validate_internal_referrer?, only: [:index]

    helper_method :in_multi_mfa_selection_flow?

    def index
      generate_codes
      result = BackupCodeSetupForm.new(current_user).submit
      visit_result = result.to_h.merge(analytics_properties_for_visit)
      analytics.backup_code_setup_visit(**visit_result)
      irs_attempts_api_tracker.mfa_enroll_backup_code(success: result.success?)

      save_backup_codes
      track_backup_codes_created
    end

    def edit
      analytics.backup_code_regenerate_visit(**analytics_properties_for_visit)
    end

    def continue
      flash[:success] = t('notices.backup_codes_configured')
      analytics.multi_factor_auth_setup(**analytics_properties)
      redirect_to next_setup_path || after_mfa_setup_path
    end

    def confirm_delete; end

    def refreshed
      @codes = user_session[:backup_codes]
      render 'index'
    end

    def delete
      current_user.backup_code_configurations.destroy_all
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
      flash[:success] = t('notices.backup_codes_deleted')
      revoke_remember_device(current_user)
      if in_multi_mfa_selection_flow?
        redirect_to authentication_methods_setup_path
      else
        redirect_to account_two_factor_authentication_path
      end
    end

    def reminder
      flash.now[:success] = t('notices.authenticated_successfully')
    end

    def confirm_backup_codes; end

    private

    def validate_internal_referrer?
      redirect_to root_url unless internal_referrer?
    end

    def internal_referrer?
      UserSessionContext.reauthentication_context?(context) ||
        session[:account_redirect_path] || in_multi_mfa_selection_flow?
    end

    def analytics_properties_for_visit
      { in_account_creation_flow: in_account_creation_flow? }
    end

    def track_backup_codes_created
      analytics.backup_code_created(
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
        in_account_creation_flow: in_account_creation_flow?,
      )
      Funnel::Registration::AddMfa.call(current_user.id, 'backup_codes', analytics)
    end

    def mfa_user
      @mfa_user ||= MfaContext.new(current_user)
    end

    def ensure_backup_codes_in_session
      redirect_to backup_code_setup_url unless user_session[:backup_codes]
    end

    def generate_codes
      revoke_remember_device(current_user) if current_user.backup_code_configurations.any?
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

    def save_backup_codes
      handle_valid_verification_for_confirmation_context(
        auth_method: TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE,
      )
      generator.save(user_session[:backup_codes])
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
      create_user_event(:backup_codes_added)
    end

    def generator
      @generator ||= BackupCodeGenerator.new(current_user)
    end

    def authorize_backup_code_disable
      return if MfaPolicy.new(current_user).multiple_factors_enabled? ||
                in_multi_mfa_selection_flow?
      redirect_to account_two_factor_authentication_path
    end

    def analytics_properties
      {
        success: true,
        multi_factor_auth_method: 'backup_codes',
        in_account_creation_flow: in_account_creation_flow?,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      }
    end
  end
end
