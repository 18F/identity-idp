# Update ServiceProvider from config/service_providers.yml (all environments in rake db:seed)
class ServiceProviderSeeder
  def initialize(rails_env: Rails.env, deploy_env: LoginGov::Hostdata.env)
    @rails_env = rails_env
    @deploy_env = deploy_env
  end

  def run
    content = ERB.new(Rails.root.join('config', 'service_providers.yml').read).result
    service_providers = YAML.load(content).fetch(rails_env, {})

    service_providers.each do |issuer, config|
      next if Figaro.env.chef_env == 'prod' && config['allow_on_prod_chef_env'] != 'true'
      ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
        sp.approved = true
        sp.active = true
        sp.native = true
        sp.attributes = config.except('allow_on_prod_chef_env')
      end
    end
  end

  private

  attr_reader :rails_env, :deploy_env
end
