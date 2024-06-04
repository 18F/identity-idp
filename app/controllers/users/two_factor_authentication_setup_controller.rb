# frozen_string_literal: true

module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :check_if_possible_piv_user

    delegate :enabled_mfa_methods_count, to: :mfa_context

    def index
      two_factor_options_form
      @presenter = two_factor_options_presenter
      analytics.user_registration_2fa_setup_visit(
        enabled_mfa_methods_count:,
        gov_or_mil_email: gov_or_mil_email?,
      )
    end

    def create
      result = submit_form
      analytics.user_registration_2fa_setup(**result.to_h)

      if result.success?
        process_valid_form
      else
        flash.now[:error] = result.first_error_message
        @presenter = two_factor_options_presenter
        render :index
      end
    end

    # @api private
    def two_factor_options_form
      @two_factor_options_form ||= TwoFactorOptionsForm.new(
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    private

    def gov_or_mil_email?
      current_user.confirmed_email_addresses.any?(&:gov_or_mil?)
    end

    def mfa_context
      @mfa_context ||= MfaContext.new(current_user)
    end

    def submit_form
      two_factor_options_form.submit(two_factor_options_form_params)
    end

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(
        user_agent: request.user_agent,
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
        show_skip_additional_mfa_link: show_skip_additional_mfa_link?,
        after_mfa_setup_path:,
        return_to_sp_cancel_path:,
      )
    end

    def process_valid_form
      user_session[:mfa_selections] = @two_factor_options_form.selection
      redirect_to(first_mfa_selection_path || after_mfa_setup_path)
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection, selection: [])
    rescue ActionController::ParameterMissing
      ActionController::Parameters.new(selection: [])
    end
  end
end
