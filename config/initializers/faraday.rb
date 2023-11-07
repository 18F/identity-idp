# frozen_string_literal: true

# Instruments Faraday requests using ActiveSupport::Notifications and Faraday's
# instrumentation middleware. This file subscribes to both 'request_metric.faraday' and
# 'request_log.faraday' events. 'request_metric.faraday' is for requests which we
# want to turn into metrics, and potentially create alarms for. These requests should be
# critical to the functionality of the IDP. Less critical requests can still be instrumented and
# logged with 'request_log.faraday'.
#
# Requests publishing to 'request_metric.faraday' must include a context that describes the request
# under the :service_name key. The value must made of non-space ASCII characters due to
# CloudWatch (https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_Dimension.html).
#
# Example instrumentation of Faraday request:
#
# Faraday.new(ssl: ssl_config) do |f|
#   f.request :instrumentation, name: 'request_metric.faraday'
# end.post(
#   verify_token_uri,
#   URI.encode_www_form({ token: token }),
#   Authentication: authenticate(token),
# ) do |req|
#   req.options.context = { service_name: 'piv_cac_token' }
# end

ActiveSupport::Notifications.subscribe('request_metric.faraday') do |name, starts, ends, _, env|
  url = env[:url]
  http_method = env[:method].to_s.upcase
  duration_seconds = ends - starts
  service = env.request.context.fetch(:service_name)
  metadata = {
    http_method:,
    host: url.host,
    path: url.path,
    duration_seconds:,
    status: env.status,
    service:,
    name: 'request_metric.faraday',
  }
  Rails.logger.info(
    metadata.to_json,
  )
end

ActiveSupport::Notifications.subscribe('request_log.faraday') do |name, starts, ends, _, env|
  url = env[:url]
  http_method = env[:method].to_s.upcase
  duration_seconds = ends - starts
  service = env.request.context&.dig(:service_name)
  metadata = {
    http_method:,
    host: url.host,
    path: url.path,
    duration_seconds:,
    status: env.status,
    service:,
    name: 'request_log.faraday',
  }
  Rails.logger.info(
    metadata.to_json,
  )
end
