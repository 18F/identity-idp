class UspsAuthTokenRefreshJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_usps_auth_token_refresh_job_started

    if token_expiration < 7.minutes
      usps_proofer.retrieve_token!
    end

    return true
  ensure
    analytics.idv_usps_auth_token_refresh_job_completed
  end

  private

  def usps_proofer
    if IdentityConfig.store.usps_mock_fallback
      UspsInPersonProofing::Mock::Proofer.new
    else
      UspsInPersonProofing::Proofer.new
    end
  end

  def token_expiration
    Rails.cache.redis.ttl(usps_proofer.AUTH_TOKEN_CACHE_KEY)
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
