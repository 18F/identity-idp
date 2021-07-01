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

      conn.options.timeout = 1
      conn.options.read_timeout = 1
      conn.options.open_timeout = 1
      conn.options.write_timeout = 1

      # raises errors on 4XX or 5XX responses
      conn.response :raise_error
    end
  end
end
