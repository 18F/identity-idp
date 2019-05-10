module JobRunner
  class LockReferee
    attr_reader :job_configuration

    def initialize(job_configuration)
      @job_configuration = job_configuration
    end

    # :reek:TooManyStatements
    def acquire_lock_and_run_callback_if_needed
      log_check_if_run_needed_message
      job_run = nil
      return unless run_needed?
      JobRun.with_lock do
        # Check again that we need to run with the lock acquired
        return log_race_lost_message unless run_needed?

        log_executing_job_message
        job_run = JobRun.create!(job_name: job_configuration.name)
      end
      CallbackExecutor.new(job_configuration: job_configuration, job_run: job_run).execute_job
      log_done_message
    end

    private

    def run_needed?
      resolver = JobRunNeededResolver.new(job_configuration)
      return true if resolver.new_job_needs_to_run?
      log_run_not_needed_message(resolver.current_job.created_at)
      false
    end

    def log_check_if_run_needed_message
      Rails.logger.info("#{job_configuration}: Checking if run is needed")
    end

    def log_race_lost_message
      race_lost_message = "#{job_configuration}: Due for run, but someone else won the race"
      Rails.logger.info(race_lost_message)
    end

    def log_executing_job_message
      Rails.logger.info("#{job_configuration}: Executing job")
    end

    def log_done_message
      Rails.logger.debug("#{job_configuration}: Done")
    end

    def log_run_not_needed_message(last_run)
      Rails.logger.info("#{job_configuration}: Not yet due to run. Last run: #{last_run}")
    end
  end
end
