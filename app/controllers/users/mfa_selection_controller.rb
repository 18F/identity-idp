module Users
  class MfaSelectionController < ApplicationController
    include UserAuthenticator
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :multiple_factors_enabled?

    def index
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      @presenter = two_factor_options_presenter
      analytics.user_registration_2fa_additional_setup_visit
    end

    def update
      result = submit_form
      analytics.user_registration_2fa_additional_setup(**result.to_h)

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
      user_session[:mfa_selections] = @two_factor_options_form.selection
      redirect_to confirmation_path(user_session[:mfa_selections].first)
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection, selection: [])
    end

    def multiple_factors_enabled?
      return if IdentityConfig.store.select_multiple_mfa_options
      redirect_to after_mfa_setup_path
    end
  end
end
