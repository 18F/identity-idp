# :reek:TooManyMethods

require 'active_support/core_ext/hash/deep_merge'
require 'logger'
require 'login_gov/hostdata'
require 'yaml'

module Deploy
  # :reek:TooManyMethods
  class Activate
    attr_reader :logger, :s3_client

    def initialize(logger: default_logger, s3_client: nil)
      @logger = logger
      @s3_client = s3_client
    end

    def run
      download_application_yml_from_s3
      deep_merge_s3_data_with_example_application_yml
      set_proper_file_permissions_for_application_yml

      download_from_s3_and_update_permissions('/common/GeoIP2-City.mmdb', geolocation_db_path)
      download_from_s3_and_update_permissions('/common/pwned-passwords.txt', pwned_passwords_path)
    end

    private

    def download_application_yml_from_s3
      LoginGov::Hostdata.s3(logger: logger, s3_client: s3_client).download_configs(
        '/%<env>s/idp/v1/application.yml' => env_yaml_path,
      )
    end

    def deep_merge_s3_data_with_example_application_yml
      File.open(result_yaml_path, 'w') { |file| file.puts YAML.dump(application_config) }
    end

    def set_proper_file_permissions_for_application_yml
      FileUtils.chmod(0o640, [env_yaml_path, result_yaml_path])
    end

    def download_from_s3_and_update_permissions(src, dest)
      download_file(src, dest)
      update_file_permissions(dest)
    end

    def download_file(src, dest)
      ec2_region = ec2_data.region

      LoginGov::Hostdata::S3.new(
        bucket: "login-gov.secrets.#{ec2_data.account_id}-#{ec2_region}",
        env: nil,
        region: ec2_region,
        logger: logger,
        s3_client: s3_client,
      ).download_configs(src => dest)
    end

    def ec2_data
      @ec2_data ||= LoginGov::Hostdata::EC2.load
    end

    def update_file_permissions(path)
      FileUtils.chmod(0o644, path)
    end

    def default_logger
      logger = Logger.new(STDOUT)
      logger.progname = 'deploy/activate'
      logger
    end

    def env_yaml_path
      File.join(root, 'config/application_s3_env.yml')
    end

    def root
      File.expand_path('../../../', __FILE__)
    end

    def application_config
      YAML.load_file(example_application_yaml_path).deep_merge(YAML.load_file(env_yaml_path))
    end

    def example_application_yaml_path
      File.join(root, 'config/application.yml.default')
    end

    def result_yaml_path
      File.join(root, 'config/application.yml')
    end

    def geolocation_db_path
      File.join(root, 'geo_data/GeoLite2-City.mmdb')
    end

    def pwned_passwords_path
      File.join(root, 'pwned_passwords/pwned_passwords.txt')
    end
  end
end
