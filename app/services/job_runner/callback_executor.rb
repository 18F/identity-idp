module JobRunner
  class CallbackExecutor
    attr_reader :job_run, :job_configuration

    def initialize(job_run:, job_configuration:)
      @job_run = job_run
      @job_configuration = job_configuration
    end

    def execute_job
      ::NewRelic::Agent::Tracer.in_transaction(
        partial_name: "JobRun/execute/#{job_run.job_name}",
        category: :task,
      ) do
        log_execution_started_message
        execute_job_and_save_result
        log_execution_completed_message
      end
    end

    private

    def execute_job_and_save_result
      job_run.result = job_configuration.callback.call
      job_run
    rescue StandardError => error
      handle_job_run_error(job_run: job_run, error: error)
      job_run
    ensure
      job_run.finish_time = Time.zone.now
      job_run.save!
    end

    def handle_job_run_error(job_run:, error:)
      job_run.error = error.inspect
      NewRelic::Agent.notice_error(error)
    end

    def log_execution_started_message
      Rails.logger.debug("#{job_configuration}: executing callback")
    end

    # :reek:DuplicateMethodCall
    def log_execution_completed_message
      if job_run.error.present?
        Rails.logger.warn("#{job_configuration}: Job failed: #{job_run.error}")
      else
        Rails.logger.info("#{job_configuration}: Job finished successfully")
      end
    end
  end
end
