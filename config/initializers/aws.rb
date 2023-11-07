pattern =
  ':client_class :http_response_status_code :time :retries :operation [:error_class :error_message]'
log_formatter = Aws::Log::Formatter.new(pattern)

Aws.config.update(
  region: IdentityConfig.store.aws_region,
  http_open_timeout: IdentityConfig.store.aws_http_timeout.to_f,
  http_read_timeout: IdentityConfig.store.aws_http_timeout.to_f,
  retry_limit: IdentityConfig.store.aws_http_retry_limit,
  retry_max_delay: IdentityConfig.store.aws_http_retry_max_delay,
  logger: ActiveSupport::Logger.new(Rails.root.join('log', 'production.log')),
  log_formatter:,
)
