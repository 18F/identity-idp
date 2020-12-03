# frozen_string_literal: true

module JobRunner
  # A subclass of the standard HealthChecker that only looks at job
  # configurations that are marked with `health_critical: true`.
  class HealthCheckerCritical < HealthChecker
    # Select only jobs with #health_critical? => true.
    def self.job_selected_for_checking?(job_configuration)
      job_configuration.health_critical?
    end
  end
end
