module AccountReset
  class PendingPresenter
    include ActionView::Helpers::DateHelper

    attr_reader :account_reset_request

    def initialize(account_reset_request)
      @account_reset_request = account_reset_request
    end

    def time_remaining_until_granted(now: Time.zone.now)
      wait_time = IdentityConfig.store.account_reset_wait_period_days.days

      distance_of_time_in_words(
        now,
        account_reset_request.requested_at + wait_time,
        true,
        highest_measures: 2,
      )
    end

    def account_reset_deletion_period_hours
      IdentityConfig.store.account_reset_wait_period_days.days.in_hours.to_i
    end
  end
end
