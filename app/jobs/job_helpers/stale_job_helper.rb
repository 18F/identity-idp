# frozen_string_literal: true

module JobHelpers
  module StaleJobHelper
    class StaleJobError < StandardError; end

    def stale_job?(enqueued_at)
      enqueued_at &&
        enqueued_at < IdentityConfig.store.async_stale_job_timeout_seconds.seconds.ago
    end

    def raise_stale_job!
      raise StaleJobError.new(
        format(
          '%s enqueued over %s seconds ago',
          self.class,
          IdentityConfig.store.async_stale_job_timeout_seconds,
        ),
      )
    end
  end
end
