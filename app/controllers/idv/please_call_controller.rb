module Idv
  class PleaseCallController < ApplicationController
    before_action :confirm_two_factor_authenticated

    FRAUD_REVIEW_CONTACT_WITHIN_DAYS = 14.days

    def show
      analytics.idv_please_call_visited
      pending_at = current_user.fraud_review_pending_profile.fraud_review_pending_at ||
                   Time.zone.today
      @call_by_date = pending_at + FRAUD_REVIEW_CONTACT_WITHIN_DAYS
    end
  end
end
