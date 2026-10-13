# frozen_string_literal: true

# Shared helpers for the account-preserving MFA recovery workflow.
#
# See docs/adr/0001-account-preserving-mfa-recovery.md.
module AccountRecoveryConcern
  include ActionView::Helpers::DateHelper

  def account_recovery_wait_period
    IdentityConfig.store.account_recovery_wait_period_days.days
  end

  # Human-readable description of how long a recovery request waits before a
  # recovery link is issued.
  def account_recovery_wait_period_interval
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time,
      current_time + account_recovery_wait_period,
      true,
      accumulate_on: account_recovery_accumulation_type,
    )
  end

  private

  def account_recovery_accumulation_type
    account_recovery_wait_period > 3.days ? :days : :hours
  end
end
