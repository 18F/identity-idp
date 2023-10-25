# frozen_string_literal: true

# Checks outbound network connections
module OutboundHealthChecker
  module_function

  # @return [HealthCheckSummary]
  def check
    jitter = rand(-5..5)
    Rails.cache.fetch('outbound_health_check', expires_in: (45 + jitter).seconds) do
      HealthCheckSummary.new(healthy: true, result: outbound_response)
    rescue StandardError => err
      NewRelic::Agent.notice_error(err)
      HealthCheckSummary.new(healthy: false, result: err.message)
    end
  end

  def outbound_response
    if IdentityConfig.store.outbound_connection_check_url.blank?
      raise 'missing outbound_connection_check_url'
    end

    response = faraday.head(IdentityConfig.store.outbound_connection_check_url) do |req|
      req.options.context = { service_name: 'outbound_health_check' }
    end

    { url: IdentityConfig.store.outbound_connection_check_url, status: response.status }
  end

  # @api private
  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.adapter :net_http

      retry_options = {
        max: IdentityConfig.store.outbound_connection_check_retry_count,
        exceptions: [
          Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed
        ],
      }
      conn.request :retry, retry_options

      conn.options.timeout = IdentityConfig.store.outbound_connection_check_timeout
      conn.options.read_timeout = IdentityConfig.store.outbound_connection_check_timeout
      conn.options.open_timeout = IdentityConfig.store.outbound_connection_check_timeout
      conn.options.write_timeout = IdentityConfig.store.outbound_connection_check_timeout

      # raises errors on 4XX or 5XX responses
      conn.response :raise_error
    end
  end
end
