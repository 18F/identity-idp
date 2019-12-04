FRIENDLY_ERROR_CONFIG =
  YAML.safe_load(
    File.read(
      File.expand_path('../../../config/friendly_error/config.yml', __FILE__),
    ),
  ).freeze
