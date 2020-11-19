class IdvController < ApplicationController
  include IdvSession
  include AccountReactivationConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_needed, only: [:fail]
  before_action :profile_needs_reactivation?, only: [:index]

  def index
    if decorated_session.requested_more_recent_verification?
      verify_identity
    elsif active_profile? && !liveness_upgrade_required?
      redirect_to idv_activated_url
    elsif idv_attempter_throttled?
      redirect_to idv_fail_url
    elsif sp_over_quota_limit?
      flash[:error] = t('errors.doc_auth.quota_reached')
      redirect_to account_url
    else
      verify_identity
    end
  end

  def activated
    redirect_to idv_url unless active_profile?
    redirect_to account_url if session[:ial2_with_no_sp_campaign]
    idv_session.clear
  end

  def fail
    redirect_to idv_url and return unless idv_attempter_throttled?
  end

  private

  def sp_over_quota_limit?
    Db::ServiceProviderQuotaLimit::IsSpOverQuota.call(sp_session[:issuer].to_s)
  end

  def verify_identity
    analytics.track_event(Analytics::IDV_INTRO_VISIT)
    if proof_with_cac?
      redirect_to idv_cac_url
    else
      redirect_to idv_doc_auth_url
    end
  end

  def profile_needs_reactivation?
    return unless reactivate_account_session.started?
    confirm_password_reset_profile
    redirect_to reactivate_account_url
  end

  def liveness_upgrade_required?
    sp_session[:ial2_strict] && !current_user.active_profile&.includes_liveness_check?
  end

  def active_profile?
    current_user.active_profile.present?
  end

  def proof_with_cac?
    AppConfig.env.cac_proofing_enabled == 'true' &&
      (Db::EmailAddress::HasGovOrMil.call(current_user) ||
      current_user.piv_cac_configurations.any?)
  end
end
