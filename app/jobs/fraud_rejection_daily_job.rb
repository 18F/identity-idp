# frozen_string_literal: true

class FraudRejectionDailyJob < ApplicationJob
  queue_as :low

  def perform(_date)
    profiles_eligible_for_fraud_rejection.find_each do |profile|
      profile.in_person_enrollment&.failed!
      profile.reject_for_fraud(notify_user: false)
      analytics(user: profile.user).automatic_fraud_rejection(
        fraud_rejection_at: profile.fraud_rejection_at,
      )
    end
  end

  private

  def analytics(user:)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  def profiles_eligible_for_fraud_rejection
    Profile.includes(:user).where(fraud_review_pending_at: ..30.days.ago)
  end
end
