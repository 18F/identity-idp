SERVICE_PROVIDERS = YAML.load_file("#{Rails.root}/config/service_providers.yml")

ServiceProviderConfig.fetch_providers_from_domain_name_or_rails_env
