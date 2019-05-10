module JobRunner
  class JobConfiguration
    attr_reader :name
    attr_reader :interval
    attr_reader :timeout
    attr_reader :callback

    # :reek:ControlParameter
    def initialize(name:, interval:, timeout: nil, callback:)
      @name = name
      @interval = interval
      @timeout = timeout || interval
      @callback = callback
    end

    def to_s
      "JobConfiguration #{name.inspect}"
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
