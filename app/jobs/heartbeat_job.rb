class HeartbeatJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info(
      {
        name: 'queue_metric.good_job',
        # borrowed from: https://github.com/bensheldon/good_job/blob/main/engine/app/controllers/good_job/dashboards_controller.rb#L35
        num_finished: GoodJob::Job.finished.count,
        num_unfinished: GoodJob::Job.unfinished.count,
        num_running: GoodJob::Job.running.count,
        num_errors: GoodJob::Job.where.not(error: nil).count,
      }.to_json,
    )

    true
  end
end
