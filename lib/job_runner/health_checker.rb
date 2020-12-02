# frozen_string_literal: true

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
        jobs = Runner.configurations.select do |job_configuration|
          job_selected_for_checking?(job_configuration)
        end

        result = jobs.map do |job_configuration|
          [job_configuration.name, successful_recent_job_run?(job_configuration)]
        end.to_h
        healthy = !result.value?(false)
        Summary.new(healthy, result)
      end

      private

      # Override this method to filter out some jobs as not checked.
      # By default, return true always and check all jobs
      #
      # @return Boolean
      #
      def job_selected_for_checking?(_job_configuration)
        true
      end

      # Return whether there has been a succesful run of the given job
      # configuration in the last N runs, where N is the job configuration's
      # defined `failures_before_alarm`.
      #
      # @param [JobConfiguration] job_configuration
      # @return [Boolean]
      #
      def successful_recent_job_run?(job_configuration)
        interval_window = job_configuration.interval * job_configuration.failures_before_alarm
        JobRun.where(job_name: job_configuration.name, error: nil).
          where('created_at > ?', interval_window.seconds.ago).
          any?
      end
    end
  end
end
