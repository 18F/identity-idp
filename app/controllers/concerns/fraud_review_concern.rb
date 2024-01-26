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

  def in_person_handle_fraud
    return unless IdentityConfig.store.in_person_proofing_enforce_tmx
    in_person_handle_pending_fraud_review
  end

  def in_person_handle_pending_fraud_review
    puts "is profile active? #{enrollment.profile.active}"
    # profile isnt active yet until we get a status update from usps
    # will need to find another way to check if we should show the screen
    redirect_to_fraud_review if fraud_review_pending? && enrollment.profile.active == false
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
