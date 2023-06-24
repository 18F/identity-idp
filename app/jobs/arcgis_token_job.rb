class ArcgisTokenJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_arcgis_token_job_started
    token_keeper.refresh_token
    return true
  ensure
    analytics.idv_arcgis_token_job_completed
  end

  private

  def token_keeper
    ArcgisApi::TokenKeeper.new
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
