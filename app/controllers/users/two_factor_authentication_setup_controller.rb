module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :confirm_user_needs_2fa_setup

    def index
      two_factor_options_form
      @presenter = two_factor_options_presenter
      analytics.user_registration_2fa_setup_visit
    end

    def create
      result = submit_form
      analytics.user_registration_2fa_setup(**result.to_h)
      irs_attempts_api_tracker.mfa_enroll_options_selected(
        success: result.success?,
        mfa_device_types: @two_factor_options_form.selection,
      )

      if result.success?
        process_valid_form
      elsif (result.errors[:selection].include? 'phone') &&
            IdentityConfig.store.kantara_2fa_phone_restricted
        flash[:phone_error] = t('errors.two_factor_auth_setup.must_select_additional_option')
        redirect_to authentication_methods_setup_path(anchor: 'select_phone')
      else
        flash[:error] = t('errors.two_factor_auth_setup.must_select_option')
        @presenter = two_factor_options_presenter
        render :index
      end
    rescue ActionController::ParameterMissing
      flash[:error] = t('errors.two_factor_auth_setup.must_select_option')
      redirect_back(fallback_location: authentication_methods_setup_path, allow_other_host: false)
    end

    private

    def submit_form
      two_factor_options_form.submit(two_factor_options_form_params)
    end

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(
        user_agent: request.user_agent,
        user: current_user,
        aal3_required: service_provider_mfa_policy.aal3_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def two_factor_options_form
      @two_factor_options_form ||= TwoFactorOptionsForm.new(
        user: current_user,
        aal3_required: service_provider_mfa_policy.aal3_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_form
      user_session[:mfa_selections] = @two_factor_options_form.selection
      redirect_to confirmation_path(user_session[:mfa_selections].first)
    end

    def confirm_user_needs_2fa_setup
      return unless mfa_policy.two_factor_enabled?
      return if service_provider_mfa_policy.user_needs_sp_auth_method_setup?
      redirect_to after_mfa_setup_path
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection, selection: [])
    end
  end
end
