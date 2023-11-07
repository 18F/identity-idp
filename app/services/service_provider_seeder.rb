# Update ServiceProvider from config/service_providers.yml (all environments in rake db:seed)
class ServiceProviderSeeder
  class ExtraServiceProviderError < StandardError; end

  def initialize(rails_env: Rails.env, deploy_env: Identity::Hostdata.env, yaml_path: 'config')
    @rails_env = rails_env
    @deploy_env = deploy_env
    @yaml_path = yaml_path
  end

  def run
    check_for_missing_sps

    service_providers.each do |issuer, config|
      next unless write_service_provider?(config)

      cert_pems = Array(config['certs']).map do |cert|
        cert_path = Rails.root.join('certs', 'sp', "#{cert}.crt")
        cert_path.read if cert_path.exist?
      end.compact

      ServiceProvider.find_or_create_by!(issuer:) do |sp|
        sp.update(
          approved: true,
          active: true,
          native: true,
          friendly_name: config['friendly_name'],
        )
      end.update!(config.except(
        'agency',
        'certs',
        'restrict_to_deploy_env',
        'protocol',
        'native',
      ).merge(certs: cert_pems))
    end
  end

  private

  attr_reader :rails_env, :deploy_env

  def service_providers
    file = Rails.root.join(@yaml_path, 'service_providers.yml').read
    file.gsub!('%{env}', deploy_env) if deploy_env
    YAML.safe_load(file, permitted_classes: [Date]).fetch(rails_env)
  rescue Psych::SyntaxError => syntax_error
    Rails.logger.error { "Syntax error loading service_providers.yml: #{syntax_error.message}" }
    raise syntax_error
  rescue KeyError => key_error
    Rails.logger.error { "Missing env in service_providers.yml?: #{key_error.message}" }
    raise key_error
  end

  def write_service_provider?(config)
    return true if rails_env != 'production'

    restrict_env = config['restrict_to_deploy_env']
    in_prod = deploy_env == 'prod'
    in_sandbox = !%w[prod staging].include?(deploy_env)
    in_staging = deploy_env == 'staging'

    return true if restrict_env == 'prod' && in_prod
    return true if restrict_env == 'staging' && in_staging
    return true if restrict_env == 'sandbox' && in_sandbox
    return true if restrict_env.blank? && !in_prod

    false
  end

  def check_for_missing_sps
    return unless %w[prod staging].include? deploy_env

    sps_in_db = ServiceProvider.pluck(:issuer)
    sps_in_yaml = service_providers.keys
    extra_sps = sps_in_db - sps_in_yaml

    return if extra_sps.empty?

    extra_sp_error = ExtraServiceProviderError.new(
      "Extra service providers found in DB: #{extra_sps.join(', ')}",
    )

    if IdentityConfig.store.team_ursula_email.present?
      ReportMailer.warn_error(
        email: IdentityConfig.store.team_ursula_email,
        error: extra_sp_error,
      ).deliver_now
    end
  end
end
