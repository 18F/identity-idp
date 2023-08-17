class UspsAuthTokenRefreshJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_usps_auth_token_refresh_job_started

    usps_proofer.retrieve_token!
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => err
    analytics.idv_usps_auth_token_refresh_job_network_error(
      exception_class: err.class.name,
      exception_message: err.message,
    )
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
