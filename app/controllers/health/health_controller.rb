module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
        account_reset: AccountResetHealthChecker,
        job_runner: JobRunner::HealthChecker,
      }
      MultiHealthChecker.new(**checkers)
    end
  end
end
