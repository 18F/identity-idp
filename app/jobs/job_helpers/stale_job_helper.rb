module JobHelpers
  module StaleJobHelper
    class StaleJobError < StandardError; end

    def stale_job?(enqueued_at)
      enqueued_at &&
        enqueued_at < IdentityConfig.store.async_stale_job_timeout_seconds.seconds.ago
    end

    def notify_stale_job
      NewRelic::Agent.notice_error(
        StaleJobError.new(
          format(
            '%s enqueued over %s seconds ago',
            self.class,
            IdentityConfig.store.async_stale_job_timeout_seconds,
          ),
        ),
      )
    end
  end
end
