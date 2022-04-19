module Users
  class BackupCodeSetupController < ApplicationController
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :ensure_backup_codes_in_session, only: %i[continue download refreshed]
    before_action :set_backup_code_setup_presenter
    before_action :apply_secure_headers_override

    def index; end

    def create
      generate_codes
      result = BackupCodeSetupForm.new(current_user).submit
      analytics.track_event(Analytics::BACKUP_CODE_SETUP_VISIT, result.to_h)
      analytics.track_event(Analytics::BACKUP_CODE_CREATED)
      Funnel::Registration::AddMfa.call(current_user.id, 'backup_codes')
      save_backup_codes
    end

    def edit; end

    def continue
      flash[:success] = t('notices.backup_codes_configured')
      next_mfa_setup_for_user = user_session.dig(
        :selected_mfa_options,
        determine_next_mfa_selection,
      )
      redirect_to user_next_authentication_setup_path(next_mfa_setup_for_user) ||
                  after_mfa_setup_path
    end

    def download
      data = user_session[:backup_codes].join("\r\n") + "\r\n"
      send_data data, filename: 'backup_codes.txt'
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
  end
end
