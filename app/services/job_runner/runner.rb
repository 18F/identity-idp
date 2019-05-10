module JobRunner
  class Runner
    def self.configurations
      @configurations ||= []
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
