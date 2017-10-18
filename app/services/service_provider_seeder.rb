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
        sp.approved = true
        sp.active = true
        sp.native = true
      end.update(config.except('restrict_to_deploy_env'))
    end
  end

  private

  attr_reader :rails_env, :deploy_env

  def service_providers
    content = ERB.new(Rails.root.join('config', 'service_providers.yml').read).result
    YAML.safe_load(content).fetch(rails_env, {})
  end

  def write_service_provider?(config)
    return true if rails_env != 'production'

    restrict_env = config['restrict_to_deploy_env']

    is_production_or_has_a_restriction = (deploy_env == 'prod' || restrict_env.present?)

    !is_production_or_has_a_restriction || (restrict_env == deploy_env)
  end
end
