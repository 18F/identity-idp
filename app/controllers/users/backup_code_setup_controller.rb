module Users
  class BackupCodeSetupController < ApplicationController
    include MfaSetupConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :ensure_backup_codes_in_session, only: %i[create download]
    before_action :set_backup_code_setup_presenter

    def index
      generate_codes
      result = BackupCodeSetupForm.new(current_user).submit
      analytics.track_event(Analytics::BACKUP_CODE_SETUP_VISIT, result.to_h)
    end

    def edit; end

    def create
      analytics.track_event(Analytics::BACKUP_CODE_CREATED)
      mark_user_as_fully_authenticated
      generator.save(user_session[:backup_codes])
      create_user_event(:backup_codes_added)
      revoke_remember_device
      redirect_to two_2fa_setup
    end

    def download
      data = user_session[:backup_codes].join("\n") + "\n"
      send_data data, filename: 'backup_codes.txt'
    end

    private

    def ensure_backup_codes_in_session
      redirect_to backup_code_setup_url unless user_session[:backup_codes]
    end

    def generate_codes
      @codes = generator.generate
      user_session[:backup_codes] = @codes
    end

    def set_backup_code_setup_presenter
      @presenter = SetupPresenter.new(current_user, user_fully_authenticated?)
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def revoke_remember_device
      UpdateUser.new(
        user: current_user, attributes: { remember_device_revoked_at: Time.zone.now },
      ).call
    end

    def generator
      @generator ||= BackupCodeGenerator.new(@current_user)
    end
  end
end
