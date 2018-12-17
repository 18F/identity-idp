module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include Authorizable

    before_action :authenticate_user
    before_action :authorize_user
    before_action :clear_backup_codes, only: [:index]

    def index
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      @presenter = two_factor_options_presenter
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP_VISIT)
    end

    def create
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      result = @two_factor_options_form.submit(two_factor_options_form_params)
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP, result.to_h)

      if result.success?
        process_valid_form
      else
        @presenter = two_factor_options_presenter
        render :index
      end
    end

    private

    def clear_backup_codes
      current_user.backup_code_configurations&.destroy_all
    end

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(current_user, current_sp)
    end

    # rubocop:disable Metrics/MethodLength
    def process_valid_form
      case @two_factor_options_form.selection
      when 'sms', 'voice'
        redirect_to phone_setup_url
      when 'auth_app'
        redirect_to authenticator_setup_url
      when 'piv_cac'
        redirect_to setup_piv_cac_url
      when 'webauthn'
        redirect_to webauthn_setup_url
      when 'backup_code'
        redirect_to backup_code_setup_url
      end
    end
    # rubocop:enable Metrics/MethodLength

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection)
    end
  end
end
