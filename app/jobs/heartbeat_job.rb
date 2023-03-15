class HeartbeatJob < ApplicationJob
  queue_as :default

  def perform
    IdentityJobLogSubscriber.new.logger.info(
      {
        name: 'queue_metric.good_job',
      }.to_json,
    )

    true
  end
end
