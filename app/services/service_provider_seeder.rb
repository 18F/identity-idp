# Update ServiceProvider from config/service_providers.yml (all environments in rake db:seed)
class ServiceProviderSeeder
  def initialize(rails_env: Rails.env, deploy_env: LoginGov::Hostdata.env)
    @rails_env = rails_env
    @deploy_env = deploy_env
  end

  # rubocop:disable Metrics/MethodLength
  def run
    service_providers.each do |issuer, config|
      next unless write_service_provider?(config)
      ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
        sp.update(approved: true,
                  active: true,
                  native: true,
                  friendly_name: config['friendly_name'])
      end.update!(config.except('restrict_to_deploy_env',
                                'uuid_priority',
                                'protocol',
                                'native'))
    end
  end
  # rubocop:enable Metrics/MethodLength

  private

  attr_reader :rails_env, :deploy_env

  # rubocop:disable Metrics/AbcSize
  #:reek:DuplicateMethodCall :reek:TooManyStatements
  def service_providers
    file = remote_setting || Rails.root.join('config', 'service_providers.yml').read
    content = ERB.new(file).result
    YAML.safe_load(content, aliases: true).fetch(rails_env)
  rescue Psych::SyntaxError => syntax_error
    Rails.logger.error { "Syntax error loading service_providers.yml: #{syntax_error.message}" }
    raise syntax_error
  rescue KeyError => key_error
    Rails.logger.error { "Missing env in service_providers.yml?: #{key_error.message}" }
    raise key_error
  end
  # rubocop:enable Metrics/AbcSize

  def remote_setting
    RemoteSetting.find_by(name: 'service_providers.yml')&.contents
  end

  def write_service_provider?(config)
    return true if rails_env != 'production'

    restrict_env = config['restrict_to_deploy_env']

    is_production_or_has_a_restriction = (deploy_env == 'prod' || restrict_env.present?)

    !is_production_or_has_a_restriction || (restrict_env == deploy_env)
  end
end
