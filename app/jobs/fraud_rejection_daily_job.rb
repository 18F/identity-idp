class FraudRejectionDailyJob < ApplicationJob
  queue_as :low

  def perform(_date)
    profiles_eligible_for_fraud_rejection.find_each do |profile|
      analytics.automatic_fraud_rejection(
        rejection_date: Time.zone.today,
        fraud_review_pending_at: profile.fraud_review_pending_at,
      )
      profile.reject_for_fraud(notify_user: false)
    end
  end

  private

  def analytics(user: AnonymousUser.new)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  def profiles_eligible_for_fraud_rejection
    Profile.where(
      fraud_review_pending: true,
      fraud_review_pending_at: ..30.days.ago,
    )
  end
end
