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
    )
  end

  def irs_attempts_api_tracker
    @irs_attempts_api_tracker ||= IrsAttemptsApi::Tracker.new
  end

  def cookies
    request.cookie_jar
  end
end
