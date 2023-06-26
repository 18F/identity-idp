# Mixin for account reset event tracking
# Assumes these methods exist on the including class:
# - sp
# - success
# - errors
# - request
# - analytics
module AccountReset::TrackIrsEvent
  def track_irs_event
    irs_attempts_api_tracker.account_reset_account_deleted(
      success: success,
      failure_reason: event_failure_reason.presence,
    )
  end

  def irs_attempts_api_tracker
    @irs_attempts_api_tracker ||= IrsAttemptsApi::Tracker.new(
      request: request,
      user: user,
      sp: sp,
      cookie_device_uuid: cookies[:device],
      sp_request_uri: nil,
      enabled_for_session: sp.irs_attempts_api_enabled?,
      analytics: analytics,
    )
  end

  def cookies
    request.cookie_jar
  end

  def event_failure_reason
    errors.is_a?(ActiveModel::Errors) ? errors.messages.to_hash : errors
  end
end
