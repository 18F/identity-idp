class UspsAuthTokenRefreshJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_usps_auth_token_refresh_job_started

    usps_proofer.retrieve_token!
  ensure
    analytics.idv_usps_auth_token_refresh_job_completed
  end

  private

  def usps_proofer
    UspsInPersonProofing::EnrollmentHelper.usps_proofer
  end

  def analytics
    @analytics ||= Analytics.new(
      user: AnonymousUser.new,
      request: nil,
      session: {},
      sp: nil,
    )
  end
end
