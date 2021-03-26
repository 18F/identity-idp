class AppConfigReader
  attr_accessor :root_path

  def initialize(
    root_path: Rails.root
  )
    @root_path = root_path
  end

  def read_configuration
    read_default_configuration.deep_merge(
      read_override_configuration,
    ).deep_merge(
      read_role_configuration,
    )
  end

  private

  def read_default_configuration
    YAML.safe_load(File.read(File.join(root_path, 'config', 'application.yml.default')))
  end

  def read_override_configuration
    local_config_filepath = File.join(root_path, 'config', 'application.yml')
    raw_configs = if Identity::Hostdata.in_datacenter?
                    app_secrets_s3.read_file('/%<env>s/idp/v1/application.yml')
                  elsif File.exists?(local_config_filepath)
                    File.read(local_config_filepath)
                  end
    YAML.safe_load(raw_configs || '{}')
  end

  def read_role_configuration
    return {} if role_configuration_filename.nil?
    local_config_filepath = File.join(root_path, 'config', role_configuration_filename)
    s3_config_filepath = "/%<env>s/idp/v1/#{role_configuration_filename}"

    raw_configs = if Identity::Hostdata.in_datacenter?
                    app_secrets_s3.read_file(s3_config_filepath)
                  elsif File.exists?(local_config_filepath)
                    File.read(local_config_filepath)
                  end

    YAML.safe_load(raw_configs || '{}')
  end

  def role_configuration_filename
    case Identity::Hostdata.instance_role
    when 'idp'
      'web.yml'
    when 'worker'
      'worker.yml'
    end
  end

  def app_secrets_s3
    @app_secrets_s3 ||= Identity::Hostdata.app_secrets_s3(s3_client: s3_client, logger: logger)
  end
end
