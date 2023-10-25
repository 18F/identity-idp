# frozen_string_literal: true

module Idv
  class PleaseCallController < ApplicationController
    include FraudReviewConcern

    before_action :confirm_two_factor_authenticated
    before_action :handle_fraud_rejection
    before_action :confirm_fraud_pending

    FRAUD_REVIEW_CONTACT_WITHIN_DAYS = 14.days

    def show
      analytics.idv_please_call_visited
      pending_at = current_user.fraud_review_pending_profile.fraud_review_pending_at
      @call_by_date = pending_at + FRAUD_REVIEW_CONTACT_WITHIN_DAYS
    end

    private

    def confirm_fraud_pending
      if !fraud_review_pending?
        redirect_to account_url
      end
    end
  end
end
