module Users
  class BackupCodeSetupController < ApplicationController
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :ensure_backup_codes_in_session, only: %i[continue download]
    before_action :set_backup_code_setup_presenter
    before_action :apply_secure_headers_override

    def index
      @presenter = BackupCodeCreatePresenter.new
    end

    def depleted
      @presenter = BackupCodeDepletedPresenter.new
    end

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
      redirect_to two_2fa_setup
    end

    def download
      data = user_session[:backup_codes].join("\r\n") + "\r\n"
      send_data data, filename: 'backup_codes.txt'
    end

    def confirm_delete; end

    def delete
      current_user.backup_code_configurations.destroy_all
      flash[:success] = t('notices.backup_codes_deleted')
      revoke_remember_device(current_user)
      redirect_to account_url
    end

    private

    def ensure_backup_codes_in_session
      redirect_to backup_code_setup_url unless user_session[:backup_codes]
    end

    def generate_codes
      revoke_remember_device(current_user) if should_revoke_remember_device_after_adding_codes?
      @codes = generator.generate
      user_session[:backup_codes] = @codes
    end

    def should_revoke_remember_device_after_adding_codes?
      # We don't want to revoke remember device if the user is setting up backup codes as their
      # second MFA
      return false unless MfaPolicy.new(current_user).sufficient_factors_enabled?
      true
    end

    def set_backup_code_setup_presenter
      @presenter = SetupPresenter.new(current_user, user_fully_authenticated?)
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def save_backup_codes
      mark_user_as_fully_authenticated
      generator.save(user_session[:backup_codes])
      create_user_event(:backup_codes_added)
    end

    def generator
      @generator ||= BackupCodeGenerator.new(@current_user)
    end
  end
end
