# add config/service_providers.yml
ServiceProviderSeeder.new.run

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
