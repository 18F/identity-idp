class AnalyticsEventJob < ActiveJob::Base
  queue_as :analytics

  TRACKER = Staccato.tracker(Figaro.env.google_analytics_key, nil, ssl: true)

  def perform(options)
    TRACKER.event(options)
  end
end
