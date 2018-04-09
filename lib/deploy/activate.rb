require 'active_support/core_ext/hash/deep_merge'
require 'logger'
require 'login_gov/hostdata'
require 'yaml'

module Deploy
  class Activate
    attr_reader :logger, :s3_client

    def initialize(logger: default_logger, s3_client: nil)
      @logger = logger
      @s3_client = s3_client
    end

    def run
      LoginGov::Hostdata.s3(logger: logger, s3_client: s3_client).download_configs(
        '/%<env>s/idp/v1/application.yml' => env_yaml_path
      )

      File.open(result_yaml_path, 'w') { |file| file.puts YAML.dump(application_config) }

      FileUtils.chmod(0o640, [env_yaml_path, result_yaml_path])
    end

    private

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
      File.join(root, 'config/application.yml.example')
    end

    def result_yaml_path
      File.join(root, 'config/application.yml')
    end
  end
end
