module JobRunner
  class Runner
    def self.configurations
      @configurations ||= []
    end

    # :reek::DuplicateMethodCall
    def run
      Rails.logger.info("#{self.class.name}: Beginning job run")
      self.class.configurations.each do |configuration|
        Rails.logger.debug("Processing #{configuration.inspect}")
        configuration.clean_up_timeouts
        configuration.run_if_needed
      end
      Rails.logger.info("#{self.class.name}: Finished job run")
    end
  end
end
