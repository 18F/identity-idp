SERVICE_PROVIDERS = YAML.load_file("#{Rails.root}/config/service_providers.yml").
                    fetch(Rails.env, {})

# merge from dashboard
require 'feature_management'
if FeatureManagement.use_dashboard_service_providers?
  Thread.new { ServiceProviderUpdater.new.run }
end
