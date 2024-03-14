class MfaConfirmationController < ApplicationController
  include MfaSetupConcern
  before_action :confirm_two_factor_authenticated
  before_action :redirect_to_backup_codes_confirm, only: [:show],
                                                   if: :backup_code_confirmation_needed?

  def show
    @content = mfa_confirmation_presenter
    analytics.user_registration_suggest_another_mfa_notice_visited
  end

  def skip
    user_session.delete(:mfa_selections)
    user_session.delete(:next_mfa_selection_choice)
    analytics.user_registration_suggest_another_mfa_notice_skipped
    analytics.user_registration_mfa_setup_complete(
      mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
      success: true,
    )
    redirect_to sign_up_completed_path
  end

  private

  def mfa_confirmation_presenter
    MfaConfirmationPresenter.new(
      show_skip_additional_mfa_link: show_skip_additional_mfa_link?,
      webauthn_platform_set_up_successful: webauthn_platform_set_up_successful?,
    )
  end

  def password
    params.require(:user)[:password]
  end

  def mfa_context
    @mfa_context ||= MfaContext.new(current_user)
  end

  def backup_code_confirmation_needed?
    !MfaPolicy.new(current_user).multiple_factors_enabled? && user_backup_codes_configured?
  end

  def webauthn_platform_set_up_successful?
    mfa_context.webauthn_platform_configurations.present?
  end

  def redirect_to_backup_codes_confirm
    redirect_to confirm_backup_codes_path
  end
end
