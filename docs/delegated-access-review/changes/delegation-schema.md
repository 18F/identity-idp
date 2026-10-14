# Create the final delegation and billing schema

Create the final registry, approval, issuance, refresh and billing evidence structures directly on main. Snapshot authentication time on the issuance record. Do not create or drop prototype tables. Review sensitivity annotations, indexes, retention ownership and additive migrations.

## Review boundary

Compare with `dcl/delegated-access/configuration-keys`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Create the final registry, approval, issuance, refresh and billing evidence structures directly on main. Snapshot authentication time on the issuance record. Do not create or drop prototype tables. Review sensitivity annotations, indexes, retention ownership and additive migrations.

## Changed files

- `db/primary_migrate/20261009100000_add_delegation_content_to_agencies.rb`
- `db/primary_migrate/20261009100100_add_delegation_application_columns_to_service_providers.rb`
- `db/primary_migrate/20261009100200_create_token_exchange_resource_servers.rb`
- `db/primary_migrate/20261009100300_add_delegation_service_provider_columns_to_service_providers.rb`
- `db/primary_migrate/20261009100400_create_delegation_grants.rb`
- `db/primary_migrate/20261009100500_add_dpop_jkt_to_identities.rb`
- `db/primary_migrate/20261009100600_add_max_access_token_seconds_to_token_exchange_resource_servers.rb`
- `db/primary_migrate/20261009100700_create_token_exchange_tokens.rb`
- `db/primary_migrate/20261009100800_create_token_exchange_refresh_tokens.rb`
- `db/primary_migrate/20261009100900_add_max_family_seconds_to_token_exchange_resource_servers.rb`
- `db/primary_migrate/20261009101000_add_delegation_max_family_seconds_to_service_providers.rb`
- `db/primary_migrate/20261009110000_add_delegation_sp_shareable_attributes_to_service_providers.rb`
- `db/primary_migrate/20261009130000_add_access_type_to_sp_return_logs.rb`
- `db/primary_migrate/20261009130100_create_sp_return_log_billing_adjustments.rb`
- `db/primary_migrate/20261010100000_add_refresh_counters_to_token_exchange_tokens.rb`
- `db/primary_migrate/20261010100100_add_expires_at_index_to_token_exchange_refresh_tokens.rb`
- `db/primary_migrate/20261010110000_add_userinfo_encrypted_response_alg_to_service_providers.rb`
- `db/primary_migrate/20261013100000_add_dpop_required_to_service_providers.rb`
- `db/schema.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
