module JobRunner
  class JobRunNeededResolver
    attr_reader :job_configuration, :current_job

    def initialize(job_configuration)
      @job_configuration = job_configuration
    end

    def new_job_needs_to_run?
      interval_threshold = Time.zone.now - job_configuration.interval
      @current_job = JobRun.where(job_name: job_configuration.name).
                     where('created_at > ?', interval_threshold).
                     order(created_at: :desc).first
      current_job.nil?
    end
  end
end
