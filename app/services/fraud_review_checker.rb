# frozen_string_literal: true

class FraudReviewChecker
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def fraud_check_failed?
    fraud_review_pending? || fraud_rejection?
  end

  def fraud_review_pending?
    user&.fraud_review_pending_profile.present?
  end

  def fraud_rejection?
    user&.fraud_rejection_profile.present?
  end

  def fraud_review_eligible?
    !!user&.fraud_review_pending_profile&.fraud_review_pending_at&.after?(30.days.ago)
  end
end
