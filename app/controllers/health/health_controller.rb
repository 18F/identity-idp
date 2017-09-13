module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      MultiHealthChecker.new(
        database: DatabaseHealthChecker,
        workers: WorkerHealthChecker
      )
    end
  end
end
