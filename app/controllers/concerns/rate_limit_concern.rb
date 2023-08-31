module RateLimitConcern
  extend ActiveSupport::Concern

  def confirm_not_rate_limited
    rate_limited = false
    %i[idv_resolution idv_doc_auth proof_address proof_ssn].each do |throttle_type|
      if rate_limit_redirect!(throttle_type)
        rate_limited = true
        break
      end
    end
    rate_limited
  end

  def rate_limit_redirect!(throttle_type)
    if idv_attempter_rate_limited?(throttle_type)
      track_rate_limited_event(throttle_type)
      rate_limited_redirect(throttle_type)
      return true
    end
  end

  def track_rate_limited_event(throttle_type)
    analytics_args = { throttle_type: throttle_type }
    throttle_context = 'single-session'

    if throttle_type == :proof_address
      analytics_args[:step_name] = :phone
    elsif throttle_type == :proof_ssn
      analytics_args[:step_name] = 'verify_info'
      throttle_context = 'multi-session'
    end

    irs_attempts_api_tracker.idv_verification_rate_limited(throttle_context: throttle_context)
    analytics.throttler_rate_limit_triggered(**analytics_args)
  end

  def rate_limited_redirect(throttle_type)
    case throttle_type
    when :idv_resolution
      redirect_to idv_session_errors_failure_url
    when :idv_doc_auth
      redirect_to idv_session_errors_throttled_url
    when :proof_address
      redirect_to idv_phone_errors_failure_url
    when :proof_ssn
      redirect_to idv_session_errors_ssn_failure_url
    end
  end

  def idv_attempter_rate_limited?(throttle_type)
    if throttle_type == :proof_ssn
      return unless pii_ssn
      Throttle.new(
        target: Pii::Fingerprinter.fingerprint(pii_ssn),
        throttle_type: :proof_ssn,
      ).throttled?
    else
      Throttle.new(
        user: idv_session_user,
        throttle_type: throttle_type,
      ).throttled?
    end
  end

  def pii_ssn
    return unless defined?(flow_session) && user_session
    pii_from_doc_ssn = flow_session[:pii_from_doc]&.[](:ssn)
    return pii_from_doc_ssn if pii_from_doc_ssn
    flow_session[:pii_from_user]&.[](:ssn)
  end
end
