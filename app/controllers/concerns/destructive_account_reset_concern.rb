# frozen_string_literal: true

module DestructiveAccountResetConcern
  def account_reset_deletion_period_interval(user)
    WaitPeriodFormatter.call(account_reset_wait_period_days(user))
  end

  def account_reset_wait_period_days(user)
    if supports_fraud_account_reset?(user)
      IdentityConfig.store.account_reset_fraud_user_wait_period_days.days
    else
      IdentityConfig.store.account_reset_wait_period_days.days
    end
  end

  def supports_fraud_account_reset?(user)
    IdentityConfig.store.account_reset_fraud_user_wait_period_days.present? &&
      fraud_state?(user)
  end

  def fraud_state?(user)
    user.fraud_review_pending? || user.fraud_rejection?
  end

  private

  def confirm_legacy_account_reset_allowed
    return if AccountRecovery::EligibilityPolicy.new(user: current_user).legacy_reset_allowed?

    redirect_to login_two_factor_options_url
  end
end
