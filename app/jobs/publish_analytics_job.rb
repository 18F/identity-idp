class PublishAnalyticsJob < ActiveJob::Base
  queue_as :analytics

  def perform(event, properties)
    Keen.publish(event, properties)
  end
end
