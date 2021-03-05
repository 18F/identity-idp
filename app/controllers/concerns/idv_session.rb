module IdvSession
  extend ActiveSupport::Concern

  included do
    before_action :redirect_if_sp_context_needed
  end

  def confirm_idv_session_started
    redirect_to idv_doc_auth_url if idv_session.applicant.blank?
  end

  def confirm_idv_attempts_allowed
    return unless idv_attempter_throttled?
    analytics.track_event(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, request_path: request.path)
    redirect_to failure_url(:fail)
  end

  def confirm_idv_needed
    if current_user.active_profile.blank? ||
       decorated_session.requested_more_recent_verification? || liveness_upgrade_required?
      return
    end

    redirect_to idv_activated_url
  end

  def liveness_upgrade_required?
    sp_session[:ial2_strict] && !current_user.active_profile&.includes_liveness_check?
  end

  def confirm_idv_vendor_session_started
    return if flash[:allow_confirmations_continue]
    redirect_to idv_doc_auth_url unless idv_session.proofing_started?
  end

  def idv_session
    @_idv_session ||= Idv::Session.new(
      user_session: user_session,
      current_user: current_user,
      issuer: sp_session[:issuer],
    )
  end

  def idv_attempter_throttled?
    Throttler::IsThrottled.call(current_user.id, :idv_resolution)
  end

  def redirect_if_sp_context_needed
    return if sp_from_sp_session.present?
    return unless Identity::Hostdata.in_datacenter?
    return if Identity::Hostdata.env != AppConfig.env.sp_context_needed_environment
    return if current_user.profiles.any?

    redirect_to account_url
  end
end
