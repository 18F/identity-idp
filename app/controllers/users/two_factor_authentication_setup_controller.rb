module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :confirm_user_needs_2fa_setup
    before_action :handle_empty_selection, only: :create

    def index
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      @presenter = two_factor_options_presenter
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP_VISIT)
    end

    def create
      result = submit_form
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP, result.to_h)

      if result.success?
        process_valid_form
      else
        @presenter = two_factor_options_presenter
        render :index
      end
    end

    private

    def submit_form
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      @two_factor_options_form.submit(two_factor_options_form_params)
    end

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(
        user_agent: request.user_agent,
        user: current_user,
        aal3_required: service_provider_mfa_policy.aal3_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_form
      case @two_factor_options_form.selection
      when 'voice', 'sms', 'phone'
        redirect_to phone_setup_url
      when 'auth_app'
        redirect_to authenticator_setup_url
      when 'piv_cac'
        redirect_to setup_piv_cac_url
      when 'webauthn'
        redirect_to webauthn_setup_url
      when 'webauthn_platform'
        redirect_to webauthn_setup_url(platform: true)
      when 'backup_code'
        redirect_to backup_code_setup_url
      end
    end

    def handle_empty_selection
      return if params[:two_factor_options_form].present?

      flash[:error] = t('errors.two_factor_auth_setup.must_select_option')
      redirect_back(fallback_location: two_factor_options_path, allow_other_host: false)
    end

    def confirm_user_needs_2fa_setup
      return unless mfa_policy.two_factor_enabled?
      return if service_provider_mfa_policy.user_needs_sp_auth_method_setup?
      redirect_to after_mfa_setup_path
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection)
    end
  end
end
