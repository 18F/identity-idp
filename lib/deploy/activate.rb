require 'active_support/core_ext/hash/deep_merge'
require 'logger'
require 'identity/hostdata'
require 'subprocess'
require 'yaml'

module Deploy
  class Activate
    attr_reader :logger, :s3_client

    def initialize(
      logger: default_logger,
      s3_client: nil,
      root: nil,
      example_application_yaml_path: nil
    )
      @logger = logger
      @s3_client = s3_client
      @root = root
      @example_application_yaml_path = example_application_yaml_path
    end

    def run
      clone_idp_config
      setup_idp_config_symlinks

      app_secrets_s3.download_file(
        s3_path: '/%<env>s/idp/v1/application.yml',
        local_path: env_yaml_path,
      )
      deep_merge_s3_data_with_example_application_yml
      set_proper_file_permissions_for_application_yml

      secrets_s3.download_file(
        s3_path: '/common/GeoIP2-City.mmdb',
        local_path: geolocation_db_path,
      )
      secrets_s3.download_file(
        s3_path: '/common/pwned-passwords.txt',
        local_path: pwned_passwords_path,
      )
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
      files_to_link =
        %w[agencies iaa_gtcs iaa_orders iaa_statuses integration_statuses integrations
           partner_account_statuses partner_accounts service_providers]

      files_to_link.each do |file|
        symlink_verbose(
          File.join(root, idp_config_checkout_name, "#{file}.yml"),
          File.join(root, "config/#{file}.yml"),
        )
      end

      # Service provider public keys
      FileUtils.mkdir_p(File.join(root, 'certs'))
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

    def app_secrets_s3
      @app_secrets_s3 ||= Identity::Hostdata.app_secrets_s3(s3_client: s3_client, logger: logger)
    end

    def secrets_s3
      @secrets_s3 ||= Identity::Hostdata.secrets_s3(s3_client: s3_client, logger: logger)
    end

    def ec2_data
      @ec2_data ||= Identity::Hostdata::EC2.load
    end

    def update_file_permissions(path)
      FileUtils.chmod(0o644, path)
    end

    def default_logger
      logger = Logger.new(STDOUT)
      logger.progname = 'deploy/activate'
      logger
    end

    def root
      @root || File.expand_path('../../../', __FILE__)
    end

    def application_config
      YAML.load_file(example_application_yaml_path).deep_merge(YAML.load_file(env_yaml_path))
    end

    def example_application_yaml_path
      @example_application_yaml_path || File.join(root, 'config/application.yml.default')
    end

    def env_yaml_path
      File.join(root, 'config/application_s3_env.yml')
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
