class ArcgisTokenJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_arcgis_token_job_started
    token_entry = token_keeper.retrieve_token
    token_keeper.save_token(token_entry, token_entry.expires_at)
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
