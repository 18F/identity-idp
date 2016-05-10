SmsSpec.driver = :'twilio-ruby'

RSpec.configure do |config|
  config.include SmsSpec::Helpers, sms: true
  config.include(RSpec::ActiveJob, sms: true)

  config.before(:each, sms: true) do
    clear_messages
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
  end
end
