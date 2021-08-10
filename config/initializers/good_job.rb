if IdentityConfig.store.ruby_workers_enabled
  Rails.application.configure do
    config.good_job.execution_mode = :external
    config.good_job.poll_interval = 5
    config.good_job.enable_cron = true
    config.good_job.queues = 'default:5,low:1;*'
    # see config/initializers/job_configurations.rb for cron schedule
  end
end
