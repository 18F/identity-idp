module JobRunner
  class JobConfiguration
    attr_reader :name
    attr_reader :interval
    attr_reader :timeout
    attr_reader :callback
    attr_reader :failures_before_alarm

    # @param [String] name The name of the job
    # @param [Integer] interval How often a job should run (seconds)
    # @param [Integer, nil] timeout How long to wait for a job to run before
    #   assuming it has timed out (seconds)
    # @param [Callable] callback The actual job code
    # @param [Boolean] health_critical Whether this job is critical enough to
    #   be incorporated in the main app health check.
    # @param [Integer] failures_before_alarm The number of acceptable failed
    #   runs before the health check should alarm.
    #
    # :reek:ControlParameter
    def initialize(name:, interval:, timeout: nil, callback:, health_critical: false,
                   failures_before_alarm: 1)
      @name = name
      @interval = interval
      @timeout = timeout || interval
      @callback = callback
      @health_critical = health_critical
      @failures_before_alarm = failures_before_alarm
    end

    def to_s
      "JobConfiguration #{name.inspect}"
    end

    def health_critical?
      if @health_critical
        true
      else
        false
      end
    end

    def run_if_needed
      Rails.logger.debug("#{self}: Running job")
      LockReferee.new(self).acquire_lock_and_run_callback_if_needed
    end

    def clean_up_timeouts
      Rails.logger.debug("#{self}: Looking for job timeouts to clean up")
      JobRun.clean_up_timeouts(job_name: name, timeout_threshold: Time.zone.now - timeout)
    end
  end
end
