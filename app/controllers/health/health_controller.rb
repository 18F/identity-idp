module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
        workers: WorkerHealthChecker,
      }
      # Don't run worker health checks if we're not using workers (i.e. if the
      # queue adapter is inline or async)
      case Rails.application.config.active_job.queue_adapter
      when :async, :inline
        checkers.delete(:workers)
      end
      MultiHealthChecker.new(**checkers)
    end
  end
end
