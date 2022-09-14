# Update ServiceProvider from config/service_providers.yml (all environments in rake db:seed)
class ServiceProviderSeeder
  class ExtraServiceProviderError < StandardError; end

  def initialize(rails_env: Rails.env, deploy_env: Identity::Hostdata.env)
    @rails_env = rails_env
    @deploy_env = deploy_env
  end

  def run
    check_for_missing_sps

    service_providers.each do |issuer, config|
      next unless write_service_provider?(config)

      cert_pems = Array(config['certs']).map do |cert|
        cert_path = Rails.root.join('certs', 'sp', "#{cert}.crt")
        cert_path.read if cert_path.exist?
      end.compact

      ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
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
    file = Rails.root.join('config', 'service_providers.yml').read
    content = ERB.new(file).result
    YAML.safe_load(content).fetch(rails_env)
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

    is_production_or_has_a_restriction = (deploy_env == 'prod' || restrict_env.present?)

    !is_production_or_has_a_restriction || (restrict_env == deploy_env)
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
    NewRelic::Agent.notice_error(extra_sp_error)
  end
end
