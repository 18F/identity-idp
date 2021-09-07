# Checks health of application instance
module InstanceHealthChecker
  module_function

  # @return [HealthCheckSummary]
  def check
    if InstanceMonitor.error_rate > 0.1
      HealthCheckSummary.new(healthy: false, result: {})
    else
      HealthCheckSummary.new(healthy: true, result: {})
    end
  end
end
