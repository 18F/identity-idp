module AccountReset
  class PendingPresenter
    include ActionView::Helpers::DateHelper

    attr_reader :account_reset_request

    def initialize(account_reset_request)
      @account_reset_request = account_reset_request
    end

    def time_remaining_until_granted(now: Time.zone.now)
      distance_of_time_in_words(
        now,
        account_reset_request.requested_at + AppConfig.env.account_reset_wait_period_days.to_i.days,
        true,
        highest_measures: 2,
      )
    end
  end
end
