# ActiveJob events documentation:
# https://edgeguides.rubyonrails.org/active_support_instrumentation.html#active-job
# https://github.com/rails/rails/blob/v6.1.3.1/activejob/lib/active_job/log_subscriber.rb
class IdentityJobLogSubscriber < ActiveSupport::LogSubscriber
  def enqueue(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]

    json = default_attributes(event, job)

    if ex
      json[:exception_class] = ex.class.name
      json[:exception_message] = ex.message

      error(json.to_json)
    elsif event.payload[:aborted]
      json[:halted] = true

      info(json.to_json)
    else
      info(json.to_json)
    end
  end

  def enqueue_at(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]

    json = default_attributes(event, job)

    if ex
      json[:exception_class] = ex.class.name
      json[:exception_message] = ex.message

      error(json.to_json)
    elsif event.payload[:aborted]
      json[:halted] = true

      info(json.to_json)
    else
      json[:scheduled_at] = scheduled_at(event)

      info(json.to_json)
    end
  end

  def perform_start(event)
    job = event.payload[:job]

    json = default_attributes(event, job).merge(
      enqueued_at: job.enqueued_at,
      queued_duration_ms: queued_duration(job),
    )

    info(json.to_json)
  end

  def perform(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]

    json = default_attributes(event, job).merge(
      enqueued_at: job.enqueued_at,
    )

    if ex
      # NewRelic?
      json[:exception_class] = ex.class.name
      json[:exception_message] = ex.message
      json[:exception_backtrace] = Array(ex.backtrace).join("\n")

      error(json.to_json)
    elsif event.payload[:aborted]
      json[:halted] = true

      error(json.to_json)
    else
      info(json.to_json)
    end
  end

  def enqueue_retry(event)
    job = event.payload[:job]
    ex = event.payload[:error]
    wait_seconds = event.payload[:wait]

    json = default_attributes(event, job).merge(
      wait_ms: wait_seconds.to_i.in_milliseconds,
    )

    json[:exception_class] = ex.class.name if ex

    if ex
      error(json.to_json)
    else
      info(json.to_json)
    end

    json
  end

  def retry_stopped(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    json = default_attributes(event, job).merge(
      exception_class: ex.class.name,
      attempts: job.executions,
    )

    error(json.to_json)
  end

  def discard(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    json = default_attributes(event, job).merge(
      exception_class: job.class,
    )

    error(json.to_json)
  end

  private

  def default_attributes(event, job)
    {
      duration_ms: event.duration,
      timestamp: Time.zone.now,
      name: event.name,
      job_class: job.class.name,
      trace_id: trace_id(job),
      queue_name: queue_name(event),
      job_id: job.job_id,
    }
  end

  def queue_name(event)
    event.payload[:adapter].class.name.demodulize.remove('Adapter') +
      "(#{event.payload[:job].queue_name})"
  end

  def queued_duration(job)
    return if job.enqueued_at.blank?
    (Time.zone.now - Time.zone.parse(job.enqueued_at)).in_milliseconds
  end

  def scheduled_at(event)
    Time.zone.at(event.payload[:job].scheduled_at).utc
  end

  def logger
    if Rails.env.test?
      Rails.logger
    else
      ActiveSupport::Logger.new(Rails.root.join('log', 'workers.log'))
    end
  end

  def trace_id(job)
    return unless Array(job&.arguments).first.is_a?(Hash)
    job.arguments.first[:trace_id]
  end
end

IdentityJobLogSubscriber.attach_to :active_job
