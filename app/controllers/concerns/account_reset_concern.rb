module AccountResetConcern
  def account_reset_deletion_period_interval
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time,
      current_time + account_reset_wait_period_days,
      true,
      accumulate_on: :hours,
    )
  end

  def account_reset_wait_period_days
    if supports_fraud_account_reset?
      IdentityConfig.store.account_reset_fraud_user_wait_period_days.days
    else
      IdentityConfig.store.account_reset_wait_period_days.days
    end
  end

  def supports_fraud_account_reset?
    (current_user.fraud_review_pending? ||
      current_user.fraud_rejection?) &&
      (IdentityConfig.store.account_reset_fraud_user_wait_period_days.days > 0)
  end
end
