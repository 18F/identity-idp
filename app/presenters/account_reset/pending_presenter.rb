require 'action_view'

module AccountReset
  class PendingPresenter
    include ActionView::Helpers::DateHelper

    attr_reader :account_reset_request
    attr_reader :time_remaining_until_granted

    def initialize(account_reset_request)
      @account_reset_request = account_reset_request
      @time_remaining_until_granted = time_remaining
    end

    private

    def time_remaining
      interval = (account_reset_request.requested_at + 24.hours - Time.zone.now).round
      duration = distance_of_time_in_words(interval).split('and')
      duration[0].sub(',', ' and ').sub(/minutes.*$/, 'minutes').squeeze(' ')
    end
  end
end
