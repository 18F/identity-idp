Rails.application.configure do
  config.good_job.execution_mode = :external
  config.good_job.poll_interval = 5
  config.good_job.enable_cron = true
  config.good_job.max_threads = IdentityConfig.store.good_job_max_threads
  config.good_job.queues = IdentityConfig.store.good_job_queues
  # see config/initializers/job_configurations.rb for cron schedule
end

# Configure GoodJob even if it's not enabled, to avoid errors if the good_job process is started,
# such as in local development.
GoodJob.active_record_parent_class = 'WorkerJobApplicationRecord'
GoodJob.retry_on_unhandled_error = false
GoodJob.on_thread_error = ->(exception) { NewRelic::Agent.notice_error(exception) }
