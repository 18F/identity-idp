class IdvController < ApplicationController
  include IdvSession
  include AccountReactivationConcern

  before_action :confirm_two_factor_authenticated
  before_action :profile_needs_reactivation?, only: [:index]

  def index
    if decorated_session.requested_more_recent_verification?
      verify_identity
    elsif active_profile? && !strict_ial2_upgrade_required?
      redirect_to idv_activated_url
    elsif idv_attempter_throttled?
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_resolution,
      )
      redirect_to idv_session_errors_failure_url
    elsif sp_over_quota_limit?
      flash[:error] = t('errors.doc_auth.quota_reached')
      redirect_to account_url
    else
      verify_identity
    end
  end

  def activated
    redirect_to idv_url unless active_profile?
    idv_session.clear
  end

  private

  def sp_over_quota_limit?
    Db::ServiceProviderQuotaLimit::IsSpOverQuota.call(sp_session[:issuer].to_s)
  end

  def verify_identity
    analytics.idv_intro_visit
    redirect_to idv_doc_auth_url
  end

  def profile_needs_reactivation?
    return unless reactivate_account_session.started?
    confirm_password_reset_profile
    redirect_to reactivate_account_url
  end

  def strict_ial2_upgrade_required?
    sp_session[:ial2_strict] && !current_user.active_profile&.strict_ial2_proofed?
  end

  def active_profile?
    current_user.active_profile.present?
  end
end
