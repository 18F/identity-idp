RSpec.configure do |config|
  config.before(:each, [twilio: true, sms: true]) do
    ActiveJob::Base.queue_adapter.enqueued_jobs = []
    ActiveJob::Base.queue_adapter.performed_jobs = []
  end
end

module Features
  module ActiveJobHelper
    def reset_job_queues
      ActiveJob::Base.queue_adapter.enqueued_jobs = []
      ActiveJob::Base.queue_adapter.performed_jobs = []
    end

    def enqueued_jobs
      ActiveJob::Base.queue_adapter.enqueued_jobs
    end

    def performed_jobs
      ActiveJob::Base.queue_adapter.performed_jobs
    end
  end
end
