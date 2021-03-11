pattern =
  ':client_class :http_response_status_code :time :retries :operation [:error_class :error_message]'
log_formatter = Aws::Log::Formatter.new(pattern)

Aws.config.update(
  region: AppConfig.env.aws_region,
  http_open_timeout: AppConfig.env.aws_http_timeout.to_f,
  http_read_timeout: AppConfig.env.aws_http_timeout.to_f,
  retry_limit: AppConfig.env.aws_http_retry_limit.to_i,
  retry_max_delay: AppConfig.env.aws_http_retry_max_delay.to_i,
  logger: ActiveSupport::Logger.new(Rails.root.join('log', 'production.log')),
  log_formatter: log_formatter,
)
