# :reek:TooManyMethods
# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/MethodLength

require 'active_support/core_ext/hash/deep_merge'
require 'logger'
require 'login_gov/hostdata'
require 'subprocess'
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
      clone_idp_config
      setup_idp_config_symlinks

      download_application_yml_from_s3
      deep_merge_s3_data_with_example_application_yml
      set_proper_file_permissions_for_application_yml

      download_from_s3_and_update_permissions('/common/GeoIP2-City.mmdb', geolocation_db_path)
      download_from_s3_and_update_permissions('/common/pwned-passwords.txt', pwned_passwords_path)
    end

    private

    # Clone the private-but-not-secret git repo
    def clone_idp_config
      private_git_repo_url = ENV.fetch('IDP_private_config_repo',
                                       'git@github.com:18F/identity-idp-config.git')
      checkout_dir = File.join(root, idp_config_checkout_name)

      cmd = ['git', 'clone', private_git_repo_url, checkout_dir]
      logger.info('+ ' + cmd.join(' '))
      Subprocess.check_call(cmd)
    end

    def idp_config_checkout_name
      'identity-idp-config'
    end

    # Set up symlinks into identity-idp-config needed for the idp to make use
    # of relevant config and assets.
    #
    def setup_idp_config_symlinks
      # service_providers.yml
      symlink_verbose(
        File.join(root, idp_config_checkout_name, 'service_providers.yml'),
        File.join(root, 'config/service_providers.yml'),
      )

      # Service provider public keys
      symlink_verbose(
        File.join(root, idp_config_checkout_name, 'certs/sp'),
        File.join(root, 'certs/sp'),
      )

      # Public assets: sp-logos
      # Inject the logo files into the app's asset folder. deploy/activate is
      # run before deploy/build-post-config, so these will be picked up by the
      # rails asset pipeline.
      logos_dir = File.join(root, idp_config_checkout_name, 'public/assets/images/sp-logos')
      Dir.entries(logos_dir).each do |name|
        next if name.start_with?('.')
        target = File.join(logos_dir, name)
        link = File.join(root, 'app/assets/images/sp-logos', name)
        symlink_verbose(target, link, force: true)
      end
    end

    def symlink_verbose(dest, link, force: false)
      logger.info("symlink: #{link.inspect} => #{dest.inspect}")
      File.unlink(link) if force && File.exist?(link)
      File.symlink(dest, link)
    end

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
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/MethodLength
