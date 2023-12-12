class RiscDeliveryJob < ApplicationJob
  queue_as :low

  NETWORK_ERRORS = [
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Faraday::SSLError,
    Errno::ECONNREFUSED,
  ].freeze

  retry_on(
    *NETWORK_ERRORS,
    wait: :polynomially_longer,
    attempts: 2,
  )
  retry_on RedisRateLimiter::LimitError,
           wait: :polynomially_longer,
           attempts: 10

  def self.warning_error_classes
    NETWORK_ERRORS + [RedisRateLimiter::LimitError]
  end

  def perform(
    event_type:,
    issuer:,
    jwt:,
    push_notification_url:,
    now: Time.zone.now,
    user: nil
  )
    response = rate_limiter(push_notification_url).attempt!(now) do
      faraday.post(
        push_notification_url,
        jwt,
        'Accept' => 'application/json',
        'Content-Type' => 'application/secevent+jwt',
      ) do |req|
        req.options.context = {
          service_name: inline? ? 'risc_http_push_direct' : 'risc_http_push_async',
        }
      end
    end

    unless response.success?
      Rails.logger.warn(
        {
          event: 'http_push_error',
          transport: inline? ? 'direct' : 'async',
          event_type: event_type,
          service_provider: issuer,
          status: response.status,
        }.to_json,
      )
    end

    track_event(
      error: response.success? ? nil : 'http_push_error',
      event_type:,
      issuer:,
      success: response.success?,
      user:,
    )
  rescue *NETWORK_ERRORS => err
    raise err if self.executions < 2 && !inline?

    Rails.logger.warn(
      {
        event: 'http_push_error',
        transport: inline? ? 'direct' : 'async',
        event_type: event_type,
        service_provider: issuer,
        error: err.message,
      }.to_json,
    )

    track_event(
      error: err.message,
      event_type:,
      issuer:,
      success: false,
      user:,
    )
  rescue RedisRateLimiter::LimitError => err
    raise err if self.executions < 10 && !inline?

    Rails.logger.warn(
      {
        event: 'http_push_rate_limit',
        transport: inline? ? 'direct' : 'async',
        event_type: event_type,
        service_provider: issuer,
        error: err.message,
      }.to_json,
    )

    track_event(
      error: err.message,
      event_type:,
      issuer:,
      success: false,
      user:,
    )
  end

  def rate_limiter(url)
    url_overrides = IdentityConfig.store.risc_notifications_rate_limit_overrides.fetch(url, {})

    RedisRateLimiter.new(
      key: "push-notification-#{url}",
      max_requests: url_overrides['max_requests'] ||
        IdentityConfig.store.risc_notifications_rate_limit_max_requests,
      interval: url_overrides['interval'] ||
        IdentityConfig.store.risc_notifications_rate_limit_interval,
    )
  end

  def faraday
    @faraday ||= Faraday.new do |f|
      f.request :instrumentation, name: 'request_log.faraday'
      f.adapter :net_http
      f.options.timeout = IdentityConfig.store.risc_notifications_request_timeout
      f.options.read_timeout = IdentityConfig.store.risc_notifications_request_timeout
      f.options.open_timeout = IdentityConfig.store.risc_notifications_request_timeout
      f.options.write_timeout = IdentityConfig.store.risc_notifications_request_timeout
    end
  end

  def inline?
    queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
  end

  def track_event(event_type:, issuer:, success:, user:, error: nil)
    analytics(user).risc_security_event_pushed(
      client_id: issuer,
      error:,
      event_type:,
      success:,
    )
  end

  def analytics(user)
    @analytics ||= Analytics.new(
      request: nil,
      session: {},
      sp: nil,
      user: user || AnonymousUser.new,
    )
  end
end
