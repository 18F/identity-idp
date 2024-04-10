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
    # If the user has not passed IPP at a post office, allow them to
    # complete another enrollment by not redirecting to please call
    # or rejection screen
    return if in_person_prevent_fraud_redirection?
    redirect_to_fraud_review if fraud_review_pending?
  end

  def handle_fraud_rejection
    return if in_person_prevent_fraud_redirection?
    redirect_to_fraud_rejection if fraud_rejection?
  end

  # Returns true if the user has not passed IPP at the post office and is
  # flagged for fraud review, or has been rejected for fraud.
  # Ultimately this is to allow users who fail at the post office to create another enrollment
  # bypassing the typical flow of showing the Please Call or Fraud Rejection screens.
  def in_person_prevent_fraud_redirection?
    IdentityConfig.store.in_person_proofing_enforce_tmx &&
      current_user.ipp_enrollment_status_not_passed? &&
      (fraud_review_pending? || fraud_rejection?)
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
