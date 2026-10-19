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
end
