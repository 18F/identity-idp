# frozen_string_literal: true

module AccountRecovery
  class PendingPresenter
    include AccountRecoveryConcern
    include ActionView::Helpers::DateHelper

    attr_reader :account_recovery_request

    def initialize(account_recovery_request)
      @account_recovery_request = account_recovery_request
    end

    def granted?
      account_recovery_request.state == AccountRecoveryRequest::GRANTED
    end

    # Floored at one minute so a request still awaiting the grant job never reads as
    # elapsed or zero time.
    def time_remaining_until_granted(now: Time.zone.now)
      granted_at = account_recovery_request.requested_at + account_recovery_wait_period

      distance_of_time_in_words(now, [granted_at, now + 1.minute].max, highest_measures: 2)
    end

    def waiting_period
      account_recovery_wait_period_interval
    end
  end
end
