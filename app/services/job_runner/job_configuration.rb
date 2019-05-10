module JobRunner
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
    end

    def to_s
      "JobConfiguration #{name.inspect}"
    end

    def run_needed?
      resolver = JobRunNeededResolver.new(self)
      return true if resolve.new_job_needs_to_run?
      Rails.logger.info("#{self}: Not yet due to run. Last run: #{resolver.current_job.created_at}")
      false
    end

    def run_if_needed
      Rails.logger.info("#{self}: Checking if run is needed")

      return false unless run_needed?

      job_run = nil

      JobRun.with_lock do
        # Recheck if run is needed with lock held to avoid race condition
        unless run_needed?
          Rails.logger.info("#{self}: Due for run, but someone else won the race")
          return false
        end

        Rails.logger.info("#{self}: Executing job")
        # Create JobRun record
      end

      execute_job(job_run: job_run)
      Rails.logger.debug("#{self}: Done")
    end

    def clean_up_timeouts
      Rails.logger.debug("#{self}: Looking for job timeouts to clean up")
      JobRun.clean_up_timeouts(job_name: name, timeout_threshold: Time.now.utc - timeout)
    end

    private

    def execute_job(job_run:)
      Rails.logger.debug("#{self}: executing callback")
      job_run = JobExecutor.new(
        job_run: job_run, job_configuration: job_configuration,
      ).execute_job
      if job_run.error.present?
        Rails.logger.warn("#{self}: Job failed: #{job_run.error}")
      else
        Rails.logger.info("#{self}: Job finished successfully")
      end
    end
  end
end
