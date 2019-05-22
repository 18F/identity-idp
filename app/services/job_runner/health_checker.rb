module JobRunner
  class HealthChecker
    Summary = Struct.new(:healthy, :result) do
      def as_json(*args)
        to_h.as_json(*args)
      end

      alias_method :healthy?, :healthy
    end

    class << self
      def check
        result = Runner.configurations.map do |job_configuration|
          [job_configuration.name, successful_job_run_within_2_intervals?(job_configuration)]
        end.to_h
        healthy = !result.value?(false)
        Summary.new(healthy, result)
      end

      private

      def successful_job_run_within_2_intervals?(job_configuration)
        interval_window = (job_configuration.interval * 2).seconds.ago
        JobRun.where(job_name: job_configuration.name).
          where('created_at > ?', interval_window).
          any?
      end
    end
  end
end
