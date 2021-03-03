# Checks outbound network connections
module OutboundHealthChecker
  module_function

  # @return [HealthCheckSummary]
  def check
    HealthCheckSummary.new(healthy: true, result: outbound_response)
  rescue StandardError => err
    NewRelic::Agent.notice_error(err)
    HealthCheckSummary.new(healthy: false, result: err.message)
  end

  def outbound_response
    raise 'missing outbound_connection_check_url' if AppConfig.env.outbound_connection_check_url.blank?

    response = faraday.get(AppConfig.env.outbound_connection_check_url)

    { url: AppConfig.env.outbound_connection_check_url, status: response.status }
  end

  # @api private
  def faraday
    Faraday.new do |conn|
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
