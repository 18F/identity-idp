module RateLimitConcern
  extend ActiveSupport::Concern

  def confirm_not_rate_limited
    rate_limited = false
    %i[idv_resolution idv_doc_auth proof_address proof_ssn].each do |rate_limit_type|
      if rate_limit_redirect!(rate_limit_type)
        rate_limited = true
        break
      end
    end
    rate_limited
  end

  def rate_limit_redirect!(rate_limit_type)
    if idv_attempter_rate_limited?(rate_limit_type)
      track_rate_limited_event(rate_limit_type)
      rate_limited_redirect(rate_limit_type)
      return true
    end
  end

  def track_rate_limited_event(rate_limit_type)
    analytics_args = { limiter_type: rate_limit_type }
    limiter_context = 'single-session'

    if rate_limit_type == :proof_address
      analytics_args[:step_name] = :phone
    elsif rate_limit_type == :proof_ssn
      analytics_args[:step_name] = 'verify_info'
      limiter_context = 'multi-session'
    end

    irs_attempts_api_tracker.idv_verification_rate_limited(limiter_context: limiter_context)
    analytics.rate_limit_reached(**analytics_args)
  end

  def rate_limited_redirect(rate_limit_type)
    case rate_limit_type
    when :idv_resolution
      redirect_to idv_session_errors_failure_url
    when :idv_doc_auth
      redirect_to idv_session_errors_rate_limited_url
    when :proof_address
      redirect_to idv_phone_errors_failure_url
    when :proof_ssn
      redirect_to idv_session_errors_ssn_failure_url
    end
  end

  def idv_attempter_rate_limited?(rate_limit_type)
    if rate_limit_type == :proof_ssn
      return unless pii_ssn
      RateLimiter.new(
        target: Pii::Fingerprinter.fingerprint(pii_ssn),
        rate_limit_type: :proof_ssn,
      ).limited?
    else
      RateLimiter.new(
        user: idv_session_user,
        rate_limit_type: rate_limit_type,
      ).limited?
    end
  end

  def pii_ssn
    return unless defined?(idv_session) && user_session
    idv_session&.ssn
  end
end
