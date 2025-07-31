# frozen_string_literal: true

# add config/service_providers.yml
if ENV['KUBERNETES_REVIEW_APP'] == 'true' && ENV['DASHBOARD_URL'].present?
  dashboard_url = ENV['DASHBOARD_URL']

  ServiceProviderSeeder.new.run_review_app(dashboard_url: dashboard_url)
else
  ServiceProviderSeeder.new.run
end

# add config/agencies.yml
AgencySeeder.new.run

# add partnerships / agreements data, note that the order matters!
if IdentityConfig.store.seed_agreements_data
  Rails.logger.info('=== Seeding agreements data ===')

  Agreements::PartnerAccountStatusSeeder.new.run
  Agreements::PartnerAccountSeeder.new.run
  Agreements::IaaGtcSeeder.new.run
  Agreements::IntegrationStatusSeeder.new.run
  Agreements::IntegrationSeeder.new.run
  Agreements::IaaOrderSeeder.new.run
end
