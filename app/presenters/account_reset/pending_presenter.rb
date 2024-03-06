module AccountReset
  class PendingPresenter
    include AccountResetConcern
    include ActionView::Helpers::DateHelper

    attr_reader :account_reset_request

    def initialize(account_reset_request)
      @account_reset_request = account_reset_request
    end

    def time_remaining_until_granted(now: Time.zone.now)
      wait_time = account_reset_wait_period_days(user)

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
        current_time + account_reset_wait_period_days(user),
        true,
        accumulate_on: reset_accumulation_type(user),
      )
    end

    def user
      account_reset_request.user
    end
  end
end
