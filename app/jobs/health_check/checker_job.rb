module HealthCheck
  class CheckerJob < ActiveJob::Base
    def perform(queue_name)
      IdentityIdp.redis.set(queue_name, 'alive')
    end
  end
end
