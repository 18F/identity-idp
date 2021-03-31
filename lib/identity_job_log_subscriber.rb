# ActiveJob events documentation:
# https://edgeguides.rubyonrails.org/active_support_instrumentation.html#active-job
# https://github.com/rails/rails/blob/v6.1.3.1/activejob/lib/active_job/log_subscriber.rb
class IdentityJobLogSubscriber < ActiveSupport::LogSubscriber
  def enqueue(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]


    json = default_attributes(event, job)

    if ex
      json[:exception_class] = ex.class
      json[:exception_message] = ex.message

      error do
        json.to_json
      end
    elsif event.payload[:aborted]
      info do
        json.to_json
      end
    else
      json[:job_id] = job.job_id

      info do
        json.to_json
      end
    end
  end

  def enqueue_at(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]

    json = default_attributes(event, job)

    if ex
      json[:exception_class] = ex.class
      json[:exception_message] = ex.message

      error do
        json.to_json
      end
    elsif event.payload[:aborted]
      json[:halted] = true

      info do
        json.to_json
      end
    else
      json[:scheduled_at] = scheduled_at(event)
      json[:job_id] = job.job_id

      info do
        json.to_json
      end
    end
  end

  def perform_start(event)
    job = event.payload[:job]

    json = {
      job_id: job.job_id,
      enqueued_at: job.enqueued_at,
      queued_duration_ms: queued_duration(job),
    }

    info do
      json.to_json
    end
  end

  def perform(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]

    json = default_attributes(event, job).merge(
      job_id: job.job_id,
      enqueued_at: job.enqueued_at,
      queued_duration_ms: queued_duration(job),
    )

    if ex
      # NewRelic?
      json[:exception_class] = ex.class
      json[:exception_message] = ex.message
      json[:exception_backtrace] = Array(ex.backtrace).join("\n")

      error do
        json.to_json
      end
    elsif event.payload[:aborted]
      json[:halted] = true

      error do
        json.to_json
      end
    else
      info do
        json.to_json
      end
    end
  end

  def enqueue_retry(event)
    job = event.payload[:job]
    ex = event.payload[:error]
    wait_seconds = event.payload[:wait]

    json = {
      job_id: job.job_id,
      wait_ms: wait.to_i.in_milliseconds
    }

    if ex
      json[:exception_class] = ex.class
    end
    info do
      json.to_json
    end
  end

  def retry_stopped(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    json = default_attributes(event, job).merge(
      job_id: job.job_id,
      exception_class: ex.class,
      attempts: job.executions,
    )

    error do
      json.to_json
    end
  end

  def discard(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    json = default_attributes(event, job).merge(
      duration_ms: event.duration,
      job_id: job.job_id,
      exception_class: job.class,
    )

    error do
      json.to_json
    end
  end

  private
  def default_attributes(event, job)
    {
      timestamp: Time.zone.now,
      name: event.name,
      job_class: job.class.name,
      trace_id: trace_id(job),
      queue_name: queue_name(event),
    }
  end

  def queue_name(event)
    event.payload[:adapter].class.name.demodulize.remove("Adapter") + "(#{event.payload[:job].queue_name})"
  end

  def queued_duration(job)
    return if job.enqueued_at.blank?
    (Time.zone.now - Time.parse(job.enqueued_at)).in_milliseconds
  end

  def scheduled_at(event)
    Time.at(event.payload[:job].scheduled_at).utc
  end

  def logger
    ActiveSupport::Logger.new(Rails.root.join('log', "#{Rails.env}.log"))
  end

  def trace_id(job)
    return unless job && job.arguments.first
    job.arguments.first[:trace_id]
  end
end

IdentityJobLogSubscriber.attach_to :active_job
