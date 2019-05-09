module JobRunner
  class Runner
    def self.configurations
      @configurations ||= []
    end

    def run
      Rails.logger.info("#{self.class.name}: Beginning job run")
      self.class.configurations.each do |configuration|
        Rails.logger.debug("Processing #{configuration.inspect}")
        configuration.clean_up_timeouts
        run_job_configuration(configuration)
      end
      Rails.logger.info("#{self.class.name}: Finished job run")
    end

    private

    def run_job_configuration(configuration)
      configuration.run_if_needed
    rescue StandardError
      # TODO: do some error handling, e.g. New Relic notice_error and then
      # keep going?
      raise
    end
  end
end
