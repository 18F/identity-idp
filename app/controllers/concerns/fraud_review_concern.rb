module FraudReviewConcern
  extend ActiveSupport::Concern

  def handle_pending_fraud_review
    redirect_to_fraud_review if fraud_review_pending?
  end

  def redirect_to_fraud_review
    redirect_to idv_setup_errors_url
  end

  def redirect_to_fraud_rejection
    redirect_to idv_setup_errors_url
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
