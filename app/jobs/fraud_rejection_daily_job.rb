class FraudRejectionDailyJob < ApplicationJob
  queue_as :default

  def perform
    fraud_review_pending_profiles.find_each do |profile|
      profile.reject_for_fraud
    end
  end

  private

  def fraud_review_pending_profiles
    Profile.where(
      fraud_review_pending: true,
      verified_at: ..30.days.ago,
    )
  end
end
