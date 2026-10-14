# frozen_string_literal: true

# Shared helpers for the account-preserving MFA recovery workflow.
#
# See docs/adr/0001-account-preserving-mfa-recovery.md.
module AccountRecoveryConcern
  def account_recovery_wait_period
    IdentityConfig.store.account_recovery_wait_period_days.days
  end

  # Human-readable description of how long a recovery request waits before a
  # recovery link is issued.
  def account_recovery_wait_period_interval
    WaitPeriodFormatter.call(account_recovery_wait_period)
  end
end
