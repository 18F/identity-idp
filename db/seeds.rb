# enable registrations by default
AppSetting.find_or_create_by!(name: 'RegistrationsEnabled') do |setting|
  setting.value = '1'
end

# add config/service_providers.yml
content = ERB.new(Rails.root.join('config', 'service_providers.yml').read).result
service_providers = YAML.load(content).fetch(Rails.env, {})

service_providers.each do |issuer, config|
  next if Figaro.env.chef_env == 'prod' && config['allow_on_prod_chef_env'] != 'true'
  ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
    sp.approved = true
    sp.active = true
    sp.native = true
    sp.attributes = config.except('allow_on_prod_chef_env')
  end
end
