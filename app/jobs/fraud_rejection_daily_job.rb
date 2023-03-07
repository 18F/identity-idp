class FraudRejectionDailyJob < ApplicationJob
  queue_as :default

  def perform
    profiles_eligible_for_fraud_rejection.find_each do |profile|
      analytics.automatic_fraud_rejection(verified_at: profile.verified_at)
      profile.reject_for_fraud(notifiy_user: false)
    end
  end

  private

  def profiles_eligible_for_fraud_rejection
    Profile.where(
      fraud_review_pending: true,
      verified_at: ..30.days.ago,
    )
  end
end
