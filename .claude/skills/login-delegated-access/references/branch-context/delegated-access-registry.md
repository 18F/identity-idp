# delegated-access-registry

## Purpose

Plan 5.1, onboarding data model and configuration. The branch turns the foundation's whole-service-provider targets into a registry: an *application* is an agency-owned `service_providers` row with consent content, owning one or more *resource servers* (API URLs); the service provider is approved on its own record; approvals are one live row per (user, service provider issuer, application). It also carries the full "broker" terminology sweep and drops every foundation table and key that contradicts the registry. First branch on `login-delegated-access`; everything else waits on its schema.

## Requirements it satisfies

FR-ONB-1 to FR-ONB-9, FR-OPS-1; the approval record behind FR-CEN-11, FR-CEN-17 and FR-CUX-13. Companion §3 (ONB-1..8 as amended in §3.4, ONB-10 to ONB-14), §10.

## What it adds / removes and why

Adds:
- `agencies`: localized `delegation_description`, `delegation_learn_more_url`, `consent_content_version`, `consent_material_version`, nullable with defaults so agencies without applications are untouched (D9, D12).
- `service_providers`, application role: `delegation_application`, `delegation_scope_value` (unique, `[a-z0-9_]{1,64}`), localized display name, description, data provided, `delegation_access_type`, learn-more URL, the version pair, `consent_approved_at`/`_by`, `allowed_delegation_service_providers` (empty means any approved service provider) (D1, D2, D7).
- `service_providers`, service provider role: `token_exchange_enabled_sp`, operator name and type, localized service description, data-handling and AI statements, `delegation_uses_ai`, policy and support links, `sp_content_version`/`sp_material_version`.
- `token_exchange_resource_servers` (identifier URL, owning application, Attempts recipient, `billing_issuer`, `certs`, `token_format`, `active`); no `token_exchange_scopes` table because the scope lives on the application row (D2). The `dpop_required` column it adds is dropped on the DPoP branch (D47).
- `token_exchange_grants` in the new shape with `source`, `remember_until`, `rails_session_id`, three content versions, `proofed_in_session`, `first_exchanged_at`, revocation fields; the model carries the validity rule (D4, D6, D8, D9).
- Seeder and updater accepting nested resource servers upserted by `identifier`, children deactivated when absent; Dashboard dependency stated in comments (D3, D10).
- `config/delegated_access.localdev.yml` and `rake delegated_access:seed` with the fictitious actors (MyBenefits Assistant; Department of Housing Support; National Retirement Administration) (D10, D51).
- Reuse review: `TokenExchangeGrant belongs_to :service_provider_record` (no per-row issuer lookups); `TokenExchangeResourceServer#warn_if_unbillable` for the seeder and updater.

Removes:
- `token_exchange_service_providers` from `application.yml`: approval is partner configuration on the SP record (FR-ONB-9, ONB-5; D7). `token_exchange_enabled` stays the master switch.
- `token_exchange_broker_settings` and auto-enrollment: conflicts with the registry-defined list the person chooses from (D4, FR-CEN-1).
- `allowed_token_exchange_brokers`: replaced by `allowed_delegation_service_providers`.
- The two foundation localdev fixtures, `docs/token-exchange.md`, and every "broker" or browser-callable identifier, string and comment (D11, ONB-14).

Configuration keys are introduced by the branch that reads them, not here (E46); only the registry's own keys land.

## Key decisions

- D1 application is the unit of consent (rejected: agency-level); D2 one scope per application (rejected: a scopes table per API).
- D3 content edited in the Dashboard, D10 seed file until then; superseded for production by D77 (config repository).
- D7 opt-in and approval on SP records (rejected: `application.yml` allow-list).
- D8 grant key (user, service provider, application) (rejected: keyed to the identity's session, since pre-approval happens outside a sign-in).
- D9 only material content changes re-ask; D12 agency content on `agencies`; D11 full terminology sweep now.

## Key files

Models: `app/models/token_exchange_resource_server.rb`, `app/models/token_exchange_grant.rb` (rewritten), `app/models/concerns/delegation_localized_content.rb`, `app/models/agency.rb`, `app/models/service_provider.rb` (`delegation_service_provider?`, `delegation_application?`, `accepts_delegation_from?`); `app/models/token_exchange_broker_setting.rb` deleted.
Services: `app/services/delegated_access_seeder.rb`, `app/services/delegation_applications.rb`, `app/services/service_provider_seeder.rb`, `app/services/service_provider_updater.rb`, `app/services/agency_seeder.rb`, `app/services/analytics_events.rb`; `app/services/token_exchange_reachable_targets.rb` deleted, `DelegationApplications` takes its place.
Controllers/views: `app/views/sign_up/completions/_delegation_consent.html.erb` and `app/views/accounts/_delegation_manage.html.erb` (renamed foundation partials, replaced by later branches), `app/controllers/accounts/connected_services/token_exchange_grants_controller.rb` (kept here, removed on the account-page branch).
Migrations: `20261009100000_add_delegation_content_to_agencies`, `20261009100100_add_delegation_application_columns_to_service_providers`, `20261009100200_create_token_exchange_resource_servers`, `20261009100300_add_delegation_service_provider_columns_to_service_providers`, `20261009100400_replace_token_exchange_grants`.
Specs: `spec/models/token_exchange_grant_spec.rb`, `spec/models/token_exchange_resource_server_spec.rb`, `spec/services/delegated_access_seeder_spec.rb`, `spec/services/service_provider_seeder_spec.rb`, `spec/services/service_provider_updater_spec.rb`, factories under `spec/factories/`.
Config/locales: `config/delegated_access.localdev.yml`, `lib/tasks/delegated_access.rake`, `config/application.yml.default`, `lib/identity_config.rb`, `config/locales/{en,es,fr,zh}.yml`.

## Commits

- `714c48ce00` FR-ONB-2, FR-ONB-3: registry of applications, their API URLs and agency content
- `986e20bc54` FR-ONB-1, FR-ONB-4: approve service providers on their record and carry their consent content
- `4a194709c3` FR-CEN-17, FR-CUX-13, FR-CEN-11: approvals keyed by person, service provider and application
- `c1fe989119` FR-ONB-7, FR-ONB-9: onboarding carries applications' API URLs; Dashboard dependency stated
- `79460e706e` FR-ONB-9: delegated_access:seed loads the fictitious actors outside production
- `a003fb6419` Vocabulary sweep: remove the superseded design document, order analytics events
- `17b9d91781` Lint: remove the extra blank lines in ServiceProviderIdentity
- `6a33165abd` FR-CEN-17: TokenExchangeGrant joins its service provider record by issuer
- `7678e817c6` FR-BIL-8: TokenExchangeResourceServer#warn_if_unbillable

## How to review

Diff against `login-delegated-access`; use `git diff $(git merge-base login-delegated-access delegated-access-registry)..delegated-access-registry` so the base's later docs commits do not appear. Check first: the five migrations (every column has `comment: 'sensitive=…'`, strong_migrations-safe, the drop-and-create in `20261009100400`), the grant validity rule in `TokenExchangeGrant`, and that no "broker" remains (`git grep -i broker` on the branch). Specs that prove it: the model specs, the seeder and updater specs, `spec/services/delegated_access_seeder_spec.rb`. Must not change for existing clients: agencies and service providers that never register an application behave as before (nullable columns with defaults); `ServiceProviderUpdater` payloads without the new keys still apply.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): `service_provider_record` association and `warn_if_unbillable` (plan 5.1 items 8, 9).
- Dashboard has none of these fields (plan 6.2); production content comes from `identity-idp-config` (D77, config-content branch).
- Held until the harness run (plan 6.1): resource-server upsert shared by seeder and updater; `SslCertsLoadable` concern; `DelegatedAccessSeeder` reusing `AgencySeeder#write_agency`; `DelegationApplications.accepting` returning a preloaded relation.

## Depends on / depended on by

Depends on `login-delegated-access` (main merged, plan section 2). Depended on by every other branch: `delegated-access-consent` reads the applications and grants; the DPoP branch drops the `dpop_required` column this one adds; the config-content branch replaces the seed task's environment guard.
