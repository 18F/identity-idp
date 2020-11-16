module Health
  class HealthController < AbstractHealthController
    private

    def health_checker
      checkers = {
        database: DatabaseHealthChecker,
        account_reset: AccountResetHealthChecker,
      }
      if job_run_healthchecks_enabled?
        checkers[:job_runner_critical] = JobRunner::HealthCheckerCritical
      end
      MultiHealthChecker.new(**checkers)
    end

    def job_run_healthchecks_enabled?
      AppConfig.env.job_run_healthchecks_enabled == 'true'
    end
  end
end
