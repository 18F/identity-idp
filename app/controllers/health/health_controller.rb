module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
        account_reset: AccountResetHealthChecker,
      }
      checkers[:job_runner_critical] = JobRunner::HealthCheckerCritical if job_run_healthchecks_enabled?
      MultiHealthChecker.new(**checkers)
    end

    def job_run_healthchecks_enabled?
      Figaro.env.job_run_healthchecks_enabled == 'true'
    end
  end
end
