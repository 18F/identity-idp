module RateLimitConcern
  extend ActiveSupport::Concern

  def confirm_not_rate_limited
    rate_limited = false
    %i[idv_resolution idv_doc_auth proof_address].each do |throttle_type|
      next if throttle_and_controller_match(throttle_type) && action_name == 'update'

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
      redirect_to idv_phone_errors_failure_url if self.class != Idv::PhoneController
    end
  end

  def throttle_and_controller_match(throttle_type)
    case throttle_type
    when :idv_resolution
      self.instance_of?(Idv::VerifyInfoController) ||
        self.instance_of?(Idv::InPerson::VerifyInfoController)
    when :idv_doc_auth
      self.instance_of?(Idv::DocumentCaptureController)
    when :proof_address
      self.instance_of?(Idv::PhoneController)
    end
  end

  def idv_attempter_rate_limited?(throttle_type)
    Throttle.new(
      user: idv_session_user,
      throttle_type: throttle_type,
    ).throttled?
  end
end
