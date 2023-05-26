module IdvSession
  extend ActiveSupport::Concern
  include EffectiveUser

  included do
    before_action :redirect_unless_effective_user
    before_action :redirect_if_sp_context_needed
  end

  def confirm_idv_needed
    return if effective_user.active_profile.blank? ||
              decorated_session.requested_more_recent_verification? ||
              effective_user.reproof_for_irs?(service_provider: current_sp)

    redirect_to idv_activated_url
  end

  def hybrid_session?
    session[:doc_capture_user_id].present?
  end

  def confirm_idv_vendor_session_started
    return if flash[:allow_confirmations_continue]
    redirect_to idv_doc_auth_url unless idv_session.proofing_started?
  end

  def idv_session
    @idv_session ||= Idv::Session.new(
      user_session: user_session,
      current_user: effective_user,
      service_provider: current_sp,
    )
  end

  def check_throttled_and_redirect
    rate_limited = false
    %i[idv_resolution idv_doc_auth proof_address].each do |throttle_type|
      if idv_attempter_throttled?(throttle_type)
        track_throttled_event(throttle_type)
        throttled_redirect(throttle_type)
        rate_limited = true
        break
      end
    end
    rate_limited
  end

  def track_throttled_event(throttle_type)
    analytics_args = { throttle_type: throttle_type }
    analytics_args[:step_name] = :phone if throttle_type == :proof_address

    irs_attempts_api_tracker.idv_verification_rate_limited(throttle_context: 'single-session')
    analytics.throttler_rate_limit_triggered(**analytics_args)
  end

  def throttled_redirect(throttle_type)
    case throttle_type
    when :idv_resolution
      redirect_to idv_session_errors_failure_url
    when :idv_doc_auth
      redirect_to idv_session_errors_throttled_url
    when :proof_address
      redirect_to idv_phone_errors_failure_url if self.class != Idv::PhoneController
    end
  end

  def idv_attempter_throttled?(throttle_type)
    Throttle.new(
      user: effective_user,
      throttle_type: throttle_type,
    ).throttled?
  end

  def redirect_unless_effective_user
    redirect_to root_url if !effective_user
  end

  def redirect_if_sp_context_needed
    return if sp_from_sp_session.present?
    return unless IdentityConfig.store.idv_sp_required
    return if effective_user.profiles.any?

    redirect_to account_url
  end
end
