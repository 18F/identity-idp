module Idv
  class SetupErrorsController < ApplicationController
    before_action :confirm_two_factor_authenticated

    FRAUD_REVIEW_CONTACT_WITHIN_DAYS = 14.days

    def show
      analytics.idv_setup_errors_visited

      @call_by_date = current_user.profiles.last.verified_at + FRAUD_REVIEW_CONTACT_WITHIN_DAYS
    end
  end
end
