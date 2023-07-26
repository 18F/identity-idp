class FraudReviewChecker
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def fraud_check_failed?
    fraud_review_pending? || fraud_rejection?
  end

  def fraud_review_pending?
    user&.fraud_review_pending?
  end

  def fraud_rejection?
    user&.fraud_rejection?
  end

  def fraud_review_eligible?
    return false unless fraud_review_pending?
    !!user&.current_profile&.fraud_review_pending_at&.after?(30.days.ago)
  end
end
