SERVICE_PROVIDERS = YAML.load_file("#{Rails.root}/config/service_providers.yml").
                    fetch(Rails.env, {})

VALID_SERVICE_PROVIDERS = JSON.parse(Figaro.env.valid_service_providers)
