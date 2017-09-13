# Helps with reading and writing queue health from Sidekiq
module WorkerHealthChecker
  module_function

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
    def perform; end
  end

  Status = Struct.new(:queue, :last_run_at, :healthy) do
    alias_method :healthy?, :healthy
  end

  Summary = Struct.new(:statuses) do
    def healthy?
      statuses.all?(&:healthy?)
    end

    def to_h
      super.merge(all_healthy: healthy?) # monitoring currently depends on "all_healthy"
    end

    def as_json(*args)
      to_h.as_json(*args)
    end
  end

  # called on an interval to enqueue a dummy job in each queue
  # @see deploy/schedule.rb
  def enqueue_dummy_jobs(queues = sidekiq_queues)
    queues.each do |queue|
      DummyJob.set(queue: queue).perform_later
    end
  end

  def sidekiq_queues
    @_queues ||= YAML.load_file(Rails.root.join('config', 'sidekiq.yml'))[:queues]
  end

  # @return [Summary]
  def check(now: Time.zone.now)
    Summary.new(statuses(now: now))
  end

  # @return [Array<Status>]
  def statuses(now: Time.zone.now)
    Sidekiq::Queue.all.map(&:name).map do |name|
      status(name, now: now)
    end
  end

  def mark_healthy!(queue_name, now: Time.zone.now)
    with_redis do |redis|
      redis.set(health_check_key(queue_name), now.to_i)
    end
  end

  # @return [Status]
  def status(queue_name, now: Time.zone.now)
    last_run_value = with_redis { |redis| redis.get(health_check_key(queue_name)) }

    last_run_at = last_run_value && Time.zone.at(last_run_value.to_i)

    Status.new(queue_name, last_run_at, healthy?(last_run_at, now: now))
  end

  # @api private
  def healthy?(last_run_at, now: Time.zone.now)
    last_run_at.present? &&
      (now.to_i - last_run_at.to_i < Figaro.env.queue_health_check_dead_interval_seconds.to_i)
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
