# frozen_string_literal: true

module AccountRecoveryConcern
  def account_recovery_wait_period
    IdentityConfig.store.account_recovery_wait_period_days.days
  end

  def account_recovery_wait_period_interval
    WaitPeriodFormatter.call(account_recovery_wait_period)
  end
  def account_recovery_token_valid_period
    WaitPeriodFormatter.call(IdentityConfig.store.account_recovery_token_valid_for_hours.hours)
  end

  private

  def reconcile_lapsed_request
    recovery_request = AccountRecoveryRequest.active_for_user(current_user)
    return if recovery_request.blank?

    recovery_state = recovery_request.state
    expired = AccountRecovery::ReconcileRequest.new(
      account_recovery_request: recovery_request,
    ).call

    return unless expired

    analytics.account_recovery_expired(recovery_state:)
    @account_recovery_request = nil
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      user: current_user,
      rate_limit_type: :account_recovery_request,
    )
  end
end
