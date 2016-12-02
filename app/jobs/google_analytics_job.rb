class GoogleAnalyticsJob < ActiveJob::Base
  queue_as :analytics

  def perform(event_name:)
    tracker = Staccato.tracker(Figaro.env.google_analytics_key, nil, ssl: true)
    tracker.event(action: event_name)
  end
end
