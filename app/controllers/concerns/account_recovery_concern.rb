# frozen_string_literal: true

module AccountRecoveryConcern
  def account_recovery_wait_period
    IdentityConfig.store.account_recovery_wait_period_days.days
  end

  def account_recovery_wait_period_interval
    WaitPeriodFormatter.call(account_recovery_wait_period)
  end
end
