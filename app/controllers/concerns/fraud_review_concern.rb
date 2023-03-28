module FraudReviewConcern
  extend ActiveSupport::Concern

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
    redirect_to idv_setup_errors_url
  end

  def redirect_to_fraud_rejection
    redirect_to idv_not_verified_url
  end

  def fraud_review_pending?
    return false unless user_fully_authenticated?
    current_user.fraud_review_pending?
  end

  def fraud_rejection?
    return false unless user_fully_authenticated?
    current_user.fraud_rejection?
  end
end
