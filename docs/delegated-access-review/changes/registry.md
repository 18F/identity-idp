# Register applications and service providers for delegation

Define application consent content, resource-server registration, service-provider opt-in, and application allowlists. Keep registry queries and onboarding separate from token issuance.

## Review boundary

Compare with `dcl/delegated-access/delegation-schema`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Define application consent content, resource-server registration, service-provider opt-in, and application allowlists. Keep registry queries and onboarding separate from token issuance.

## Changed files

- `app/models/agency.rb`
- `app/models/concerns/delegation_localized_content.rb`
- `app/models/service_provider.rb`
- `app/models/token_exchange_resource_server.rb`
- `app/services/agency_seeder.rb`
- `app/services/delegation_applications.rb`
- `app/services/service_provider_seeder.rb`
- `app/services/service_provider_updater.rb`
- `spec/factories/service_providers.rb`
- `spec/factories/token_exchange_resource_servers.rb`
- `spec/models/agency_spec.rb`
- `spec/models/service_provider_spec.rb`
- `spec/models/token_exchange_resource_server_spec.rb`
- `spec/services/delegation_applications_spec.rb`
- `spec/services/service_provider_seeder_spec.rb`
- `spec/services/service_provider_updater_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
