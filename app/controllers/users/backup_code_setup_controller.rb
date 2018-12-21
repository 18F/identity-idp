module Users
  class BackupCodeSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

    def index
      generate_codes
      result = BackupCodeSetupForm.new(current_user).submit
      analytics.track_event(Analytics::BACKUP_CODE_SETUP_VISIT, result.to_h)
      mark_user_as_fully_authenticated
    end

    def create
      analytics.track_event(Analytics::BACKUP_CODE_CREATED)
      Event.create(user_id: current_user.id, event_type: :backup_codes_added)
      redirect_to sign_up_personal_key_url
    end

    def download
      data = current_user.backup_code_configurations.map(&:code).join("\n") + "\n"
      send_data data, filename: 'backup_codes.txt'
    end

    private

    def generate_codes
      @presenter = TwoFactorAuthCode::BackupCodePresenter.new(data: { current_user: current_user },
                                                              view: view_context)
      generator = BackupCodeGenerator.new(@current_user)
      @codes = generator.generate
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def two_factor_enabled?
      MfaPolicy.new(current_user).two_factor_enabled?
    end
  end
end
