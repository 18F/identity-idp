# frozen_string_literal: true

module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include MfaSetupConcern
    include AbTestingConcern
    include ApplicationHelper
    include ThreatMetrixHelper
    include ThreatMetrixConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :check_if_possible_piv_user
    before_action :override_csp_for_threat_metrix,
                  if: :account_creation_threatmetrix_bootstrap_needed?

    delegate :enabled_mfa_methods_count, to: :mfa_context

    def index
      two_factor_options_form
      analytics.user_registration_2fa_setup_visit(
        enabled_mfa_methods_count:,
        gov_or_mil_email: fed_or_mil_email?,
        in_account_creation_flow: in_account_creation_flow?,
        auto_passkey_prompted: auto_passkey_prompted?,
      )
      if auto_passkey_prompt_eligible?
        trigger_auto_passkey_setup
      else
        render_index
      end
    end

    def create
      result = submit_form
      analytics.user_registration_2fa_setup(**result)
      user_session[:platform_authenticator_available] =
        params[:platform_authenticator_available] == 'true'

      if result.success?
        process_valid_form
      else
        flash.now[:error] = result.first_error_message
        render_index
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

    def fed_or_mil_email?
      current_user.confirmed_email_addresses.any?(&:fed_or_mil_email?)
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

    def render_index
      @presenter = two_factor_options_presenter
      render :index, locals: account_creation_threatmetrix_variables
    end

    def trigger_auto_passkey_setup
      user_session[:auto_passkey_prompted] = true
      redirect_to webauthn_setup_url(platform: true, auto_trigger: true)
    end

    def auto_passkey_prompt_eligible?
      auto_passkey_prompt_available? && auto_passkey_prompt_bucket == :auto_passkey_prompt
    end

    def auto_passkey_prompted?
      user_session[:auto_passkey_prompted] == true
    end

    def auto_passkey_prompt_available?
      FeatureManagement.account_creation_passkey_auto_prompt_enabled? &&
        in_account_creation_flow? &&
        !auto_passkey_prompted?
    end

    def auto_passkey_prompt_bucket
      return unless auto_passkey_prompt_available?

      @auto_passkey_prompt_bucket ||= ab_test_bucket(:PASSKEY_UPSELL)
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection, selection: [])
    rescue ActionController::ParameterMissing
      ActionController::Parameters.new(selection: [])
    end
  end
end
