module Health
  class JobsController < AbstractHealthController
    private

    def health_checker
      JobRunner::HealthChecker
    end
  end
end
