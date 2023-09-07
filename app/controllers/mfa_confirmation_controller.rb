class MfaConfirmationController < ApplicationController
  include MfaSetupConcern
  before_action :confirm_two_factor_authenticated

  def show
    @content = mfa_confirmation_presenter
    analytics.user_registration_suggest_another_mfa_notice_visited
  end

  def skip
    user_session.delete(:mfa_selections)
    user_session.delete(:next_mfa_selection_choice)
    user_session.delete(:in_account_creation_flow)
    analytics.user_registration_suggest_another_mfa_notice_skipped
    analytics.user_registration_mfa_setup_complete(
      mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
      success: true,
    )
    redirect_to after_skip_path
  end

  private

  def mfa_confirmation_presenter
    MfaConfirmationPresenter.new(
      show_skip_additional_mfa_link: show_skip_additional_mfa_link?,
    )
  end

  def password
    params.require(:user)[:password]
  end

  def mfa_context
    @mfa_context ||= MfaContext.new(current_user)
  end

  def after_skip_path
    if backup_code_confirmation_needed?
      confirm_backup_codes_path
    else
      user_session.delete(:in_account_creation_flow)
      after_mfa_setup_path
    end
  end

  def backup_code_confirmation_needed?
    !MfaPolicy.new(current_user).multiple_factors_enabled? && user_backup_codes_configured?
  end
end
