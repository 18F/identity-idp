module Idv
  class SetupErrorsController < ApplicationController
    before_action :confirm_two_factor_authenticated

    FRAUD_REVIEW_CONTACT_WITHIN_DAYS = 14.days

    def show
      analytics.idv_setup_errors_visited
      verified_at = current_user.profiles.last.verified_at || Date.today
      @call_by_date = verified_at + FRAUD_REVIEW_CONTACT_WITHIN_DAYS
    end
  end
end
