module JobRunner
  class Runner
    def self.configurations
      @configurations ||= []
    end

    def self.run
      Rails.logger.info('Starting job runs')
      configurations.each do |c|
        Rails.logger.debug("Processing #{c.inspect}")
        c.run_if_needed
      end
    end
  end

  class JobConfiguration
    attr_reader :name
    attr_reader :interval
    attr_reader :timeout
    attr_reader :callback

    def initialize(name:, interval:, timeout: 1.year, callback:)
      @name = name
      @interval = interval
      @timeout = timeout
      @callback = callback

      Runner.configurations << self
    end

    def run_needed?
      !JobRun.where(
        'job_name = :name AND created_at > :interval_threshold AND
        (finish_time IS NOT NULL OR created_at > :timeout_threshold)',
        name: name,
        interval_threshold: Time.zone.now - interval,
        timeout_threshold: Time.zone.now - timeout,
      ).exists?
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def run_if_needed
      return false unless run_needed?

      jr = nil

      JobRun.with_lock do
        # Check for race condition
        return false unless run_needed?

        Rails.logger.info("Executing job #{name.inspect}")
        jr = JobRun.create!(job_name: name)
      end

      jr.result = callback.call
      jr.errored = false
      jr.finish_time = Time.zone.now
      jr.save!

      jr
    rescue StandardError
      if jr
        jr.errored = true
        jr.update
      end
      raise
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end
