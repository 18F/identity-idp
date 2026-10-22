# frozen_string_literal: true

module AccountRecovery
  class NewMfaSetupController < ApplicationController
    before_action :confirm_replacement_mfa_pending

    def show
      prepare_selection
    end

    def create
      prepare_selection
      result = @two_factor_options_form.submit(selection: Array(selection_params[:selection]))

      if result.success? && allowed_selection?(@two_factor_options_form.selection)
        user_session[:platform_authenticator_available] =
          params[:platform_authenticator_available] == 'true'
        user_session[:context] = 'confirmation'
        set_mfa_selections(@two_factor_options_form.selection)
        redirect_to first_mfa_selection_path
      else
        flash.now[:error] = result.first_error_message ||
                            t('errors.two_factor_auth_setup.must_select_option')
        render :show
      end
    end

    private

    def confirm_replacement_mfa_pending
      render_not_found unless replacement_mfa_pending?
    end

    def allowed_selection?(selection)
      allowed_choices = @presenter.options.reject(&:disabled?).map { |option| option.type.to_s }
      selection.present? && (selection - allowed_choices).empty?
    end

    def prepare_selection
      @two_factor_options_form = TwoFactorOptionsForm.new(
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
      @presenter = TwoFactorOptionsPresenter.new(
        user: current_user,
        user_agent: request.user_agent,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
        show_skip_additional_mfa_link: false,
      )
    end

    def selection_params
      params.fetch(:two_factor_options_form, ActionController::Parameters.new)
        .permit(selection: [])
    end
  end
end
