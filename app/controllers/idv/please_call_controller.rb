module Idv
  class PleaseCallController < ApplicationController
    before_action :confirm_two_factor_authenticated

    FRAUD_REVIEW_CONTACT_WITHIN_DAYS = 14.days

    def show
      analytics.idv_please_call_visited
      rejected_at = current_user.profiles.last.fraud_rejection_at || Time.zone.today
      @call_by_date = rejected_at + FRAUD_REVIEW_CONTACT_WITHIN_DAYS
    end
  end
end
