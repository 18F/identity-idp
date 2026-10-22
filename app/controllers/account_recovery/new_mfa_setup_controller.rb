# frozen_string_literal: true

module AccountRecovery
  class NewMfaSetupController < ApplicationController
    before_action :confirm_replacement_mfa_pending

    def show
      prepare_selection
    end

    def create
      prepare_selection
      selected = Array(selection_params[:selection])
      result = @two_factor_options_form.submit(selection: selected)
      allowed_choices = @presenter.options.reject(&:disabled?).map { |option| option.type.to_s }
      if result.success? && @two_factor_options_form.selection.one? &&
         (@two_factor_options_form.selection - allowed_choices).empty?
        user_session[:platform_authenticator_available] =
          params[:platform_authenticator_available] == 'true'
        user_session[:context] = 'confirmation'
        redirect_to confirmation_path(@two_factor_options_form.selection.first)
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
