class ArcgisTokenJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_arcgis_token_job_started
    token_keeper.retrieve_token
    return true
  rescue StandardError => e
    analytics.idv_arcgis_token_failure(
      exception_class: 'ArcGIS',
      exception_message: e.message,
      response_body_present: false,
      response_body: '',
      response_status_code: '',
      api_status_code: '',
    )
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
