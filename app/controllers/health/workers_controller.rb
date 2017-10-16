module Health
  class WorkersController < AbstractHealthController
    private

    def health_checker
      WorkerHealthChecker
    end
  end
end
