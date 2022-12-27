module Users
  class MfaSelectionController < ApplicationController
    include UserAuthenticator
    include SecureHeadersConcern
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup

    def index
      two_factor_options_form
      @after_setup_path = after_mfa_setup_path
      @presenter = two_factor_options_presenter
      analytics.user_registration_2fa_additional_setup_visit
    end

    def update
      result = submit_form
      analytics.user_registration_2fa_additional_setup(**result.to_h)

      if result.success?
        process_valid_form
      elsif (result.errors[:selection].include? 'phone') &&
            IdentityConfig.store.kantara_2fa_phone_restricted
        flash[:phone_error] = t('errors.two_factor_auth_setup.must_select_additional_option')
        redirect_to two_factor_options_path(anchor: 'select_phone')
      else
        flash[:error] = t('errors.two_factor_auth_setup.must_select_additional_option')
        redirect_back(fallback_location: second_mfa_setup_path, allow_other_host: false)
      end
    rescue ActionController::ParameterMissing
      flash[:error] = t('errors.two_factor_auth_setup.must_select_option')
      redirect_back(fallback_location: two_factor_options_path, allow_other_host: false)
    end

    private

    def submit_form
      two_factor_options_form.submit(two_factor_options_form_params)
    end

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(
        user_agent: request.user_agent,
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def two_factor_options_form
      @two_factor_options_form ||= TwoFactorOptionsForm.new(
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_form
      user_session[:mfa_selections] = @two_factor_options_form.selection

      if user_session[:mfa_selections].first.present?
        redirect_to confirmation_path(user_session[:mfa_selections].first)
      else
        redirect_to after_mfa_setup_path
      end
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection, selection: [])
    end
  end
end
