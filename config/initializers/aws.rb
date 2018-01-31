Aws.config.update(
  region: Figaro.env.aws_region,
  http_open_timeout: Figaro.env.aws_http_timeout.to_i,
  http_read_timeout: Figaro.env.aws_http_timeout.to_i
)
