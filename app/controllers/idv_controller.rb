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
    idv_session.clear
  end

  def fail
    redirect_to idv_url and return unless idv_attempter_throttled?
  end

  private

  def verify_identity
    if proof_with_cac?
      redirect_to idv_cac_url
    elsif doc_auth_enabled_and_exclusive?
      redirect_to idv_doc_auth_url
    else
      analytics.track_event(Analytics::IDV_INTRO_VISIT)
      redirect_to idv_jurisdiction_url
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
    Figaro.env.cac_proofing_enabled == 'true' && Db::EmailAddress::HasGovOrMil.call(current_user)
  end

  def doc_auth_enabled_and_exclusive?
    # exclusive mode replaces the existing LOA3 flow with the doc auth flow
    # non-exclusive mode allows both flows to co-exist
    # in non-exclusive mode you enter the /verify/doc_auth path in the browser
    FeatureManagement.doc_auth_enabled? && FeatureManagement.doc_auth_exclusive?
  end
end
