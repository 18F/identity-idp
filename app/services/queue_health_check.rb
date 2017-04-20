class QueueHealthCheck
  QUEUES = %w(sms voice analytics mailers).freeze

  def perform
    QUEUES.each do |job|
      redis.set(job, 'dead')
      HealthCheck::CheckerJob.set(queue: job).perform_later(job)
    end
  end

  private

  def redis
    IdentityIdp.redis
  end
end
