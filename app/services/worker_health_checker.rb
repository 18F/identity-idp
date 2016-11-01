# Helps with reading and writing queue health from Sidekiq
module WorkerHealthChecker
  module_function

  # Reported directly to NewRelic when a queue appears unhealthy
  class QueueHealthError < StandardError; end

  # Sidekiq server-side middleware that wraps jobs and marks the queues as healthy
  # when a job completes successfully
  class Middleware
    def call(_worker, _job, queue)
      yield

      WorkerHealthChecker.mark_healthy!(queue)
    end
  end

  # Empty job that we put in each background queue to make sure the queue is running
  # Relies on the Middleware to mark the queue as healthy
  class DummyJob < ActiveJob::Base
    def perform
    end
  end

  # called on an interval to enqueues a dummy job in each queue
  # @see deploy/schedule.rb
  def enqueue_dummy_jobs
    Sidekiq::Queue.all.each do |queue|
      DummyJob.set(queue: queue.name).perform_later
    end
  end

  # Called on an interval to check background queue health and report errors to NewRelic
  # @see deploy/schedule.rb
  def check
    Sidekiq::Queue.all.map(&:name).each do |name|
      next if healthy?(name)

      NewRelic::Agent.notice_error(
        QueueHealthError.new("Background queue #{name} is unhealthy")
      )
    end
  end

  def mark_healthy!(queue_name, now: Time.zone.now)
    with_redis do |redis|
      redis.set(health_check_key(queue_name), now.to_i)
    end
  end

  # Checks that a queue has had a job run successfully recently
  # @return [true, false]
  def healthy?(queue_name, now: Time.zone.now)
    queue_last_run = with_redis { |redis| redis.get(health_check_key(queue_name)) }

    queue_last_run.present? &&
      (now.to_i - queue_last_run.to_i < Figaro.env.queue_health_check_dead_interval_seconds.to_i)
  end

  # @api private
  def health_check_key(queue_name)
    "health:#{queue_name}"
  end

  # @api private
  # This makes reek complain less about referencing things less than self
  def with_redis(&block)
    Sidekiq.redis(&block)
  end
end
