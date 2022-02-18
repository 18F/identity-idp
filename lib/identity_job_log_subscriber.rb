# ActiveJob events documentation:
# https://edgeguides.rubyonrails.org/active_support_instrumentation.html#active-job
# https://github.com/rails/rails/blob/v6.1.3.1/activejob/lib/active_job/log_subscriber.rb
class IdentityJobLogSubscriber < ActiveSupport::LogSubscriber
  def enqueue(event)
    job = event.payload[:job]
    ex = event.payload[:exception_object]
    json = default_attributes(event, job)

    if ex
      if duplicate_cron_error?(ex)
        json[:exception_class_warn] = ex.class.name
        # The "exception_message" key flags this as an error in our alerting, so
        # this uses a different name intentionally to avoid triggering alerts
        json[:exception_message_warn] = ex.message

        warn(json.to_json)
      elsif should_error?(job, ex)
        json[:exception_class] = ex.class.name
        json[:exception_message] = ex.message

        error(json.to_json)
      else
        json[:exception_class_warn] = ex.class.name
        json[:exception_message_warn] = ex.message

        warn(json.to_json)
      end
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
      if should_error?(job, ex)
        json[:exception_class] = ex.class.name
        json[:exception_message] = ex.message

        error(json.to_json)
      else
        json[:exception_class_warn] = ex.class.name
        json[:exception_message_warn] = ex.message

        warn(json.to_json)
      end
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
      if should_error?(job, ex)
        json[:exception_class] = ex.class.name
        json[:exception_message] = ex.message
        json[:exception_backtrace] = Array(ex.backtrace).join("\n")

        error(json.to_json)
      else
        json[:exception_class_warn] = ex.class.name
        json[:exception_message_warn] = ex.message
        json[:exception_backtrace_warn] = Array(ex.backtrace).join("\n")

        warn(json.to_json)
      end
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

    if ex
      if should_error?(job, ex)
        json[:exception_class] = ex.class.name
        error(json.to_json)
      else
        json[:exception_class_warn] = ex.class.name
        info(json.to_json)
      end
    end

    json
  end

  def retry_stopped(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    if should_error?(job, ex)
      json = default_attributes(event, job).merge(
        exception_class: ex.class.name,
        attempts: job.executions,
      )

      error(json.to_json)
    else
      json = default_attributes(event, job).merge(
        exception_class_warn: ex.class.name,
        attempts: job.executions,
      )

      warn(json.to_json)
    end
  end

  def discard(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    if should_error?(job, ex)
      json = default_attributes(event, job).merge(
        exception_class: job.class,
      )

      error(json.to_json)
    else
      json = default_attributes(event, job).merge(
        exception_class_warn: job.class,
      )

      warn(json.to_json)
    end
  end

  def logger
    if Rails.env.test?
      Rails.logger
    else
      IdentityJobLogSubscriber.worker_logger
    end
  end

  def self.worker_logger
    @worker_logger ||= ActiveSupport::Logger.new(Rails.root.join('log', 'workers.log'))
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

  def trace_id(job)
    return unless Array(job&.arguments).first.is_a?(Hash)
    job.arguments.first[:trace_id]
  end

  def duplicate_cron_error?(ex)
    ex.is_a?(ActiveRecord::RecordNotUnique) && ex.message.include?('(cron_key, cron_at)')
  end

  def should_error?(job, ex)
    return true if ex.nil?

    job.class.warning_error_classes.none? { |warning_class|
      ex.is_a? warning_class
    }
  end
end

IdentityJobLogSubscriber.attach_to :active_job
