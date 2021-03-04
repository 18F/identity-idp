Aws.config.update(
  region: Identity::Hostdata.settings.aws_region,
  http_open_timeout: Identity::Hostdata.settings.aws_http_timeout.to_f,
  http_read_timeout: Identity::Hostdata.settings.aws_http_timeout.to_f,
  retry_limit: Identity::Hostdata.settings.aws_http_retry_limit.to_i,
  retry_max_delay: Identity::Hostdata.settings.aws_http_retry_max_delay.to_i,
)
