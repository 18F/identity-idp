# Update ServiceProvider from config/service_providers.yml (all environments in rake db:seed)
class ServiceProviderSeeder
  def initialize(rails_env: Rails.env, deploy_env: LoginGov::Hostdata.env)
    @rails_env = rails_env
    @deploy_env = deploy_env
  end

  def run
    service_providers.each do |issuer, config|
      next unless write_service_provider?(config)

      ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
        sp.update({
          approved: true,
          active: true,
          native: true,
          friendly_name: config["friendly_name"]
        })
      end.update!(config.except('restrict_to_deploy_env', 'uuid_priority'))
    end
  end

  private

  attr_reader :rails_env, :deploy_env

  def service_providers
    file = remote_setting || Rails.root.join('config', 'service_providers.yml').read
    content = ERB.new(file).result
    YAML.safe_load(content).fetch(rails_env, {})
  end

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
