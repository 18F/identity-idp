class RiscDeliveryJob < ApplicationJob
  queue_as :low

  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :exponentially_longer

  def perform(
    push_notification_url:,
    jwt:,
    event_type:,
    issuer:,
    transport:
  )
    response = faraday.post(
      push_notification_url,
      jwt,
      'Accept' => 'application/json',
      'Content-Type' => 'application/secevent+jwt',
    ) do |req|
      req.options.context = {
        service_name: transport == 'ruby_worker' ? 'risc_http_push_async' : 'risc_http_push_direct'
      }
    end

    unless response.success?
      Rails.logger.warn(
        {
          event: 'http_push_error',
          transport: transport,
          event_type: event_type,
          service_provider: issuer,
          status: response.status,
        }.to_json,
      )
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => err
    raise err if transport == 'ruby_worker'

    Rails.logger.warn(
      {
        event: 'http_push_error',
        transport: 'direct',
        event_type: event_type,
        service_provider: issuer,
        error: err.message,
      }.to_json,
    )
  end

  def faraday
    Faraday.new do |f|
      f.request :instrumentation, name: 'request_log.faraday'
      f.adapter :net_http
      f.options.timeout = 3
      f.options.read_timeout = 3
      f.options.open_timeout = 3
      f.options.write_timeout = 3
    end
  end
end
