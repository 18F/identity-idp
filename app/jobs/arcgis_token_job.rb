# Refresh the ArcGIS API token
#
# Keeping this behavior in a job reduces the latency and probability
# of user-facing errors related to the post office search for in-person
# proofing.
class ArcgisTokenJob < ApplicationJob
  queue_as :default

  def perform
    analytics.idv_arcgis_token_job_started
    geocoder.retrieve_token!
    return true
  ensure
    analytics.idv_arcgis_token_job_completed
  end

  private

  def geocoder
    @geocoder ||= ArcgisApi::GeocoderFactory.new.create
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
