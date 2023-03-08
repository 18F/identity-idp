class IdvController < ApplicationController
  include IdvSession
  include AccountReactivationConcern
  include FraudReviewConcern
  include SessionHelper

  before_action :confirm_two_factor_authenticated
  before_action :handle_pending_fraud_review
  before_action :profile_needs_reactivation?, only: [:index]

  def index
    if decorated_session.requested_more_recent_verification? ||
       current_user.decorate.reproof_for_irs?(service_provider: current_sp)
      verify_identity
    elsif active_profile?
      redirect_to idv_activated_url
    elsif idv_attempter_throttled?
      irs_attempts_api_tracker.idv_verification_rate_limited(throttle_context: 'single-session')
      analytics.throttler_rate_limit_triggered(
        throttle_type: :idv_resolution,
      )
      redirect_to idv_session_errors_failure_url
    else
      clear_session if enrollment_status == 'expired'
      verify_identity
    end
  end

  def activated
    redirect_to idv_url unless active_profile?
    idv_session.clear
  end

  private

  def enrollment_status
    InPersonEnrollment.where(user_id: current_user.id).order(enrollment_established_at: :desc).pick(:status)
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

  def active_profile?
    current_user.active_profile.present?
  end
end
