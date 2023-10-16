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
    analytics.user_registration_suggest_another_mfa_notice_skipped
    analytics.user_registration_mfa_setup_complete(
      mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
      success: true,
    )
    # only call the following if not ial2
    analytics.user_registration_complete(**registration_complete_event_attributes('proof-of-concept')) if !sp_session[:ial2]
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
      after_mfa_setup_path
    end
  end

  def backup_code_confirmation_needed?
    !MfaPolicy.new(current_user).multiple_factors_enabled? && user_backup_codes_configured?
  end

  def registration_complete_event_attributes(page_occurence)
    { 
      ial2: sp_session[:ial2],
      ialmax: sp_session[:ialmax],
      service_provider_name: decorated_sp_session.sp_name,
      sp_session_requested_attributes: sp_session[:requested_attributes],
      sp_request_requested_attributes: service_provider_request.requested_attributes,
      page_occurence: page_occurence,
      in_account_creation_flow: user_session[:in_account_creation_flow] || false,
      needs_completion_screen_reason: needs_completion_screen_reason
    }
  end

end
