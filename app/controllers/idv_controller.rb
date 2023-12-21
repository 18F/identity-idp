class IdvController < ApplicationController
  include IdvSession
  include AccountReactivationConcern
  include VerifyProfileConcern
  include RateLimitConcern

  before_action :confirm_two_factor_authenticated
  before_action :profile_needs_reactivation?, only: [:index]
  before_action :handle_pending_profile, only: [:index]
  before_action :confirm_not_rate_limited

  def index
    if decorated_sp_session.requested_more_recent_verification? ||
       current_user.reproof_for_irs?(service_provider: current_sp)
      verify_identity
    elsif active_profile?
      redirect_to idv_activated_url
    else
      verify_identity
    end
  end

  def activated
    if idv_session.personal_key.present?
      redirect_to idv_personal_key_url
      return
    end

    redirect_to idv_url unless active_profile?
    idv_session.clear
  end

  private

  def verify_identity
    analytics.idv_intro_visit
    redirect_to idv_welcome_url
  end

  def handle_pending_profile
    redirect_to url_for_pending_profile_reason if user_has_pending_profile?
  end

  def profile_needs_reactivation?
    return unless reactivate_account_session.started?
    confirm_password_reset_profile
    redirect_to reactivate_account_url
  end

  def active_profile?
    current_user.active_profile.present?
  end
end
