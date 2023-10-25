# frozen_string_literal: true

module FraudReviewConcern
  extend ActiveSupport::Concern

  delegate :fraud_check_failed?,
           :fraud_review_pending?,
           :fraud_rejection?,
           to: :fraud_review_checker

  def handle_fraud
    handle_pending_fraud_review
    handle_fraud_rejection
  end

  def handle_pending_fraud_review
    redirect_to_fraud_review if fraud_review_pending?
  end

  def handle_fraud_rejection
    redirect_to_fraud_rejection if fraud_rejection?
  end

  def redirect_to_fraud_review
    redirect_to idv_please_call_url
  end

  def redirect_to_fraud_rejection
    redirect_to idv_not_verified_url
  end

  def fraud_review_checker
    @fraud_review_checker ||= FraudReviewChecker.new(current_user)
  end
end
