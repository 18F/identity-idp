# enable registrations by default
AppSetting.find_or_create_by!(name: 'RegistrationsEnabled') do |setting|
  setting.value = '1'
end

# add config/service_providers.yml
SERVICE_PROVIDERS.each do |issuer, config|
  ServiceProvider.find_or_create_by!(issuer: issuer) do |sp|
    sp.approved = true
    sp.active = true
    sp.native = true
    sp.attributes = config
  end
end
