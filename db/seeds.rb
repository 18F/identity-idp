# add config/service_providers.yml
ServiceProviderSeeder.new.run

# add config/agencies.yml
AgencySeeder.new.run

# add partnerships / agreements data, note that the order matters!
Agreements::PartnerAccountStatusSeeder.new.run
Agreements::PartnerAccountSeeder.new.run
Agreements::IaaStatusSeeder.new.run
Agreements::IaaGtcSeeder.new.run
Agreements::IntegrationStatusSeeder.new.run
Agreements::IntegrationSeeder.new.run
Agreements::IaaOrderSeeder.new.run
