Aws.config.update(
  region: AppConfig.env.aws_region,
  http_open_timeout: AppConfig.env.aws_http_timeout.to_i,
  http_read_timeout: AppConfig.env.aws_http_timeout.to_i,
)
