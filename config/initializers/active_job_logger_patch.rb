# This overrides the ActiveJob logger to remove sensitive info from the logs,
# such as Devise tokens, OTP codes, phone numbers, emails, and data sent to
# Google Analytics.
ActiveSupport.on_load :active_job do # rubocop:disable Metrics/BlockLength
  module ActiveJob
    module Logging
      class LogSubscriber
        def enqueue(event)
          info { json_for(event: event, event_type: 'Enqueued') }
        end

        def perform_start(event)
          info { json_for(event: event, event_type: 'Performing') }
        end

        def perform(event)
          info { json_for(event: event, event_type: 'Performed') }
        end

        private

        def json_for(event:, event_type:)
          job = event.payload[:job]

          {
            timestamp: Time.zone.now,
            event_type: event_type,
            job_class: job.class.name,
            job_queue: queue_name(event),
            job_id: job.job_id,
            duration: "#{event.duration.round(2)}ms",
          }.to_json
        end

        def args_info(_job)
          ''
        end
      end
    end
  end
end
