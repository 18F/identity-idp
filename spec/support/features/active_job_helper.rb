module Features
  module ActiveJobHelper
    def reset_job_queues
      adapter.enqueued_jobs = []
      adapter.performed_jobs = []
    end

    def adapter
      ActiveJob::Base.queue_adapter
    end
  end
end
