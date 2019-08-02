module JobRunner
  # The Runner class manages the list of known configurations and is
  # responsible for running all of them in turn when {#run} is called.
  class Runner
    # The list of known job configurations. Calling {#run} will execute these
    # jobs according to their schedules. Add new configurations to this list by
    # calling {.add_config} aka {.add_configuration}.
    #
    # @return [Array<JobRunner::JobConfiguration>]
    #
    def self.configurations
      @configurations ||= []
      # dup and freeze so that callers have to use add_config to add jobs
      @configurations.dup.freeze
    end

    # Empty the job configurations list.
    def self.clear_configurations
      @configurations = []
    end

    # Load the disabled job list from config. Provides a way to disable jobs
    # without changing code.
    def self.disabled_jobs
      @disabled_jobs ||= JSON.parse(Figaro.env.recurring_jobs_disabled_names!)
    end

    # Add a new job configuration to the list of jobs to run. This is the
    # primary entrypoint for users to add new jobs.
    #
    # @param [JobRunner::JobConfiguration] job_config
    #
    # @see .configurations
    #
    def self.add_configuration(job_config)
      unless job_config.is_a?(JobRunner::JobConfiguration)
        raise ArgumentError, 'job_config must be a JobRunner::JobConfiguration'
      end

      if disabled_jobs.include?(job_config.name)
        Rails.logger.warn("JobRunner: skipping disabled job: #{job_config.name.inspect}")
        return false
      end

      @configurations ||= []
      @configurations << job_config
    end

    class << self
      alias add_config add_configuration
    end

    def run
      log_beginning_to_run_message
      self.class.configurations.each do |configuration|
        log_running_configuration_message(configuration)
        configuration.clean_up_timeouts
        configuration.run_if_needed
      end
      log_finished_run_message
    end

    private

    def log_beginning_to_run_message
      Rails.logger.info("#{self.class.name}: Beginning job run")
    end

    def log_running_configuration_message(job_configuration)
      Rails.logger.debug("Processing #{job_configuration.inspect}")
    end

    def log_finished_run_message
      Rails.logger.info("#{self.class.name}: Finished job run")
    end
  end
end
