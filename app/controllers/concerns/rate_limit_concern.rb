module RateLimitConcern
  extend ActiveSupport::Concern

  def confirm_not_rate_limited # confusing returns false if not rate_limited
    rate_limited = false

    throttle_types.each do |throttle_type|
      if rate_limit_redirect!(throttle_type)
        rate_limited = true
        break
      end
    end
    rate_limited
  end

  def throttle_types
    case self.class
    when Idv::PhoneController
      [:proof_address]
    when Idv::InPerson::VerifyInfoController, Idv::VerifyInfoController
      [:idv_resolution]#, :proof_ssn]
    when Idv::DocumentCaptureController
      [:idv_doc_auth]
    else
      [:proof_address, :idv_resolution, :idv_doc_auth] #, :proof_ssn] default or for spec?
    end
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
    analytics_args[:step_name] = :phone if throttle_type == :proof_address

    irs_attempts_api_tracker.idv_verification_rate_limited(throttle_context: 'single-session')
    analytics.throttler_rate_limit_triggered(**analytics_args)
  end

  def rate_limited_redirect(throttle_type)
    case throttle_type
    when :idv_resolution
      redirect_to idv_session_errors_failure_url
    when :idv_doc_auth
      redirect_to idv_session_errors_throttled_url
    when :proof_address
      redirect_to idv_phone_errors_failure_url# if self.class != Idv::PhoneController
    end
  end

  def idv_attempter_rate_limited?(throttle_type)
    Throttle.new(
      user: idv_session_user,
      throttle_type: throttle_type,
    ).throttled?
  end
end
