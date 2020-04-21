class IdvController < ApplicationController
  include IdvSession
  include AccountReactivationConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_needed, only: [:fail]
  before_action :profile_needs_reactivation?, only: [:index]

  def index
    if active_profile?
      redirect_to idv_activated_url
    elsif idv_attempter_throttled?
      redirect_to idv_fail_url
    else
      verify_identity
    end
  end

  def activated
    redirect_to idv_url unless active_profile?
    redirect_to_account_if_quota_reached
    redirect_to account_url if session[:ial2_with_no_sp_campaign]
    idv_session.clear
  end

  def fail
    redirect_to idv_url and return unless idv_attempter_throttled?
  end

  private

  def redirect_to_account_if_quota_reached
    return unless Db::ServiceProviderQuotaLimit::IsSpOverQuota.call(sp_session[:issuer].to_s)
    flash[:error] = t('errors.doc_auth.quota_reached')
    redirect_to account_url
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

  def active_profile?
    current_user.active_profile.present?
  end

  def proof_with_cac?
    Figaro.env.cac_proofing_enabled == 'true' &&
      (Db::EmailAddress::HasGovOrMil.call(current_user) ||
      current_user.piv_cac_configurations.any?)
  end
end
