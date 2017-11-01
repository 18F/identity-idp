# enable registrations by default
AppSetting.find_or_create_by!(name: 'RegistrationsEnabled') do |setting|
  setting.value = '1'
end

# add config/service_providers.yml
ServiceProviderSeeder.new.run
