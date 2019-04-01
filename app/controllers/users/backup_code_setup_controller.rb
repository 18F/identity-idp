module Users
  class BackupCodeSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?
    before_action :ensure_backup_codes_in_session, only: %i[create download]

    def index
      generate_codes
      result = BackupCodeSetupForm.new(current_user).submit
      analytics.track_event(Analytics::BACKUP_CODE_SETUP_VISIT, result.to_h)
    end

    def create
      analytics.track_event(Analytics::BACKUP_CODE_CREATED)
      mark_user_as_fully_authenticated
      generator.save(user_session[:backup_codes])
      create_user_event(:backup_codes_added)
      revoke_remember_device
      FeatureManagement.force_multiple_auth_methods? ? redirect_to enforce_mfa_policy :
                                                       redirect_to sign_up_personal_key_url
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
      @presenter = TwoFactorAuthCode::BackupCodePresenter.new(data: { current_user: current_user },
                                                              view: view_context)
      @codes = generator.generate
      user_session[:backup_codes] = @codes
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

    def two_factor_enabled?
      MfaPolicy.new(current_user).two_factor_enabled?
    end

    def generator
      @generator ||= BackupCodeGenerator.new(@current_user)
    end
  end
end
