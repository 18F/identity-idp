module AccountReset
  class PendingPresenter
    include ActionView::Helpers::DateHelper

    attr_reader :account_reset_request

    def initialize(account_reset_request)
      @account_reset_request = account_reset_request
    end

    def time_remaining_until_granted(now: Time.zone.now)
      wait_time = account_reset_wait_period_days

      distance_of_time_in_words(
        now,
        account_reset_request.requested_at + wait_time,
        true,
        highest_measures: 2,
      )
    end

    def account_reset_deletion_period
      current_time = Time.zone.now

      distance_of_time_in_words(
        current_time,
        current_time + account_reset_wait_period_days,
        true,
        accumulate_on: reset_accumulation_type,
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
      (account_reset_request_user.fraud_review_pending? ||
        account_reset_request_user.fraud_rejection?) &&
        (IdentityConfig.store.account_reset_fraud_user_wait_period_days.present?)
    end

    def account_reset_request_user
      account_reset_request.user
    end

    def reset_accumulation_type
      if account_reset_wait_period_days > 3
        :days
      else
        :hours
      end
    end
  end
end
