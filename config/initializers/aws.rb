Aws.config.update(
  region: AppConfig.env.aws_region,
  http_open_timeout: AppConfig.env.aws_http_timeout.to_f,
  http_read_timeout: AppConfig.env.aws_http_timeout.to_f,
  retry_limit: AppConfig.env.aws_http_retry_limit.to_i,
  retry_max_delay: AppConfig.env.aws_http_retry_max_delay.to_i,
)
