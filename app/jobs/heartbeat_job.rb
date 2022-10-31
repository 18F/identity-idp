class HeartbeatJob < ApplicationJob
  queue_as :default

  def perform
    IdentityJobLogSubscriber.new.logger.info(
      {
        name: 'queue_metric.good_job',
        gc_stat: GC.stat,
        object_space: ObjectSpace.count_objects,
        pid: Process.pid,
        # borrowed from: https://github.com/bensheldon/good_job/blob/main/engine/app/controllers/good_job/dashboards_controller.rb#L35
        # num_finished: GoodJob::Execution.finished.count,
        # num_unfinished: GoodJob::Execution.unfinished.count,
        # num_running: GoodJob::Execution.running.count,
        # num_errors: GoodJob::Execution.where.not(error: nil).count,
      }.to_json,
    )

    true
  end
end
