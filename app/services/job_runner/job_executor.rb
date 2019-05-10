module JobRunner
  class JobExecutor
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
        execute_job_and_save_result
      end
    end

    private

    def execute_job_and_save_result
      job_run.result = job_configuration.callback.call
      job_run
    rescue StandardError => error
      job_run.error = error.inspect
      NewRelic::Agent.notice_error(error)
      job_run
    ensure
      job_run.finish_time = Time.zone.now
      job_run.save!
    end
  end
end
