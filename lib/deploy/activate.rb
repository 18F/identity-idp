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
      root: nil
    )
      @logger = logger
      @s3_client = s3_client
      @root = root
    end

    def run
      clone_idp_config
      setup_idp_config_symlinks

      download_from_secrets_s3_unless_exists(
        s3_path: '/common/GeoIP2-City.mmdb',
        local_path: geolocation_db_path,
      )
      download_from_secrets_s3_unless_exists(
        s3_path: '/common/pwned-passwords.txt',
        local_path: pwned_passwords_path,
      )
    end

    private

    # Clone the private-but-not-secret git repo
    def clone_idp_config
      private_git_repo_url = ENV.fetch(
        'IDP_private_config_repo',
        'git@github.com:18F/identity-idp-config.git',
      )
      checkout_dir = File.join(root, idp_config_checkout_name)

      cmd = ['git', 'clone', '--depth', '1', '--branch', 'main', private_git_repo_url, checkout_dir]
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
      FileUtils.mkdir_p(File.join(root, 'public/assets/sp-logos'))
      logos_dir = File.join(root, idp_config_checkout_name, 'public/assets/images/sp-logos')
      Dir.entries(logos_dir).each do |name|
        next if name.start_with?('.')
        target = File.join(logos_dir, name)
        link = File.join(root, 'app/assets/images/sp-logos', name)
        symlink_verbose(target, link, force: true)
        link = File.join(root, 'public/assets/sp-logos', name)
        symlink_verbose(target, link, force: true)
      end
    end

    def symlink_verbose(dest, link, force: false)
      logger.info("symlink: #{link.inspect} => #{dest.inspect}")
      File.unlink(link) if force && File.exist?(link)
      File.symlink(dest, link)
    end

    def download_from_secrets_s3_unless_exists(s3_path:, local_path:)
      if File.exist?(local_path) || File.symlink?(local_path)
        logger.info("Skipping #{local_path}") && return
      end
      secrets_s3.download_file(
        s3_path: s3_path,
        local_path: local_path,
      )
    end

    def secrets_s3
      @secrets_s3 ||= Identity::Hostdata.secrets_s3(s3_client: s3_client, logger: logger)
    end

    def default_logger
      logger = Logger.new(STDOUT)
      logger.progname = 'deploy/activate'
      logger
    end

    def root
      @root || File.expand_path('../../../', __FILE__)
    end

    def geolocation_db_path
      File.join(root, 'geo_data/GeoLite2-City.mmdb')
    end

    def pwned_passwords_path
      File.join(root, 'pwned_passwords/pwned_passwords.txt')
    end
  end
end
