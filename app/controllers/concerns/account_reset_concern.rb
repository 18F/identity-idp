# frozen_string_literal: true

module AccountResetConcern
  include ActionView::Helpers::DateHelper
  def account_reset_deletion_period_interval(user)
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time,
      current_time + account_reset_wait_period_days(user),
      true,
      accumulate_on: reset_accumulation_type(user),
    )
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

  def reset_accumulation_type(user)
    if account_reset_wait_period_days(user) > 3.days
      :days
    else
      :hours
    end
  end
end
