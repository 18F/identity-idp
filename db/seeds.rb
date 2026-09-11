# frozen_string_literal: true

seed_runner = SeedRunner.new

# add config/service_providers.yml
if ENV['KUBERNETES_REVIEW_APP'] == 'true' && ENV['DASHBOARD_URL'].present?
  dashboard_url = ENV['DASHBOARD_URL']

  # This should never be invoked in production.
  # If we change how production is deployed, we should revisit the above conditionals to ensure
  # production never runs this.
  seed_runner.run(
    ServiceProviderSeeder.new,
    name: 'ServiceProviderSeeder#run_review_app',
  ) { |seeder| seeder.run_review_app(dashboard_url: dashboard_url) }
  seed_runner.run(ReviewAppUserSeeder.new, &:run)
else
  seed_runner.run(ServiceProviderSeeder.new, &:run)
end

# add config/agencies.yml
seed_runner.run(AgencySeeder.new, &:run)

# add partnerships / agreements data, note that the order matters!
if IdentityConfig.store.seed_agreements_data
  Rails.logger.info('=== Seeding agreements data ===')

  seed_runner.run(Agreements::PartnerAccountStatusSeeder.new, &:run)
  seed_runner.run(Agreements::PartnerAccountSeeder.new, &:run)
  seed_runner.run(Agreements::IaaGtcSeeder.new, &:run)
  seed_runner.run(Agreements::IntegrationStatusSeeder.new, &:run)
  seed_runner.run(Agreements::IntegrationSeeder.new, &:run)
  seed_runner.run(Agreements::IaaOrderSeeder.new, &:run)
end

seed_runner.finish!
