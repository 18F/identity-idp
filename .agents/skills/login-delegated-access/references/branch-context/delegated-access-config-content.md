# delegated-access-config-content

## Purpose

Plan 5.17, content seeded from `identity-idp-config`. The agencies' consent content, the service providers approved for delegation and the applications with their logos and API URLs are seeded by `rake db:seed` from `config/delegated_access.yml` in every environment: in deployed environments the file is linked from the configuration repository at deploy (as `service_providers.yml` and `agencies.yml` are), locally and in CI it is the fixture `config/delegated_access.localdev.yml`. The seed task's refusal of `prod` and `staging` goes; `restrict_to_deploy_env` on each entry replaces it. Top of the stack; one commit.

## Requirements it satisfies

FR-ONB-3, FR-ONB-5 and FR-ONB-9 as amended 2026-10-10 (and FR-ONB-1, FR-ONB-2 through the same seeder). Companion §3.5 (ONB-5 and ONB-12 as amended, ONB-15).

## What it adds / removes and why

Adds:
- `DelegatedAccessSeeder` reads `config/delegated_access.yml` (`yaml_path:` for specs): ERB, then `YAML.safe_load`, then `fetch(rails_env, {})`; a missing file or dangling symlink (`Pathname#exist?`) seeds nothing and raises nothing. `agencies` (keyed by agency id) are written when `restrict_to_deploy_env` allows, with that key stripped; `service_providers` (keyed by issuer) go through `ServiceProviderSeeder#write_service_provider`, so nested `token_exchange_resource_servers`, certificate lookup and the restriction behave as for every other service provider.
- `DeployEnvRestriction` (`app/services/deploy_env_restriction.rb`): the rule `ServiceProviderSeeder#write_service_provider?` carried inline, now shared: read only when `RAILS_ENV=production`; `prod` in prod only, `staging` in staging only, `sandbox` in every other deployed environment, blank everywhere except prod; in development and test every entry is written.
- `db/seeds.rb` runs the seeder through `SeedRunner` after `AgencySeeder`; `delegated_access` joins `Deploy::Activate::FILES_TO_LINK`; `bin/setup` links the fixture when `config/delegated_access.yml` is absent; `/config/delegated_access.yml` in `.gitignore`; `.gitlab-ci.yml` and `dockerfiles/idp_review_app.Dockerfile` copy the fixture into place.
- The fixture keyed by Rails environment: `development` is the content as before and remains the contract with the reference applications (D51); `production` repeats the entries with `restrict_to_deploy_env: 'sandbox'` and hosts from `DELEGATION_SP_URL`, `DELEGATION_OIDC_AGENCY_URL`, `DELEGATION_SAML_AGENCY_URL`, so a personal sandbox seeds the hosted reference applications; API identifiers never change with the hostname.
- `rake delegated_access:seed` kept as a convenience running the same seeder; comments on `AgencySeeder`, `ServiceProviderSeeder` and the two registry migrations reworded to say the fields come from the delegated-access configuration file in every environment.

Removes: the `RefusedEnvironment` error and the `prod`/`staging` refusal of the seed task (plan 5.1 item 8, 7.4 item 3); an environment that should hold no fictitious content has no file, no section, or only `sandbox`-restricted entries.

## Key decisions

- D77 content as YAML in `identity-idp-config`, reviewed by pull request, seeded everywhere (rejected: an admin content form inside identity-idp, a new authenticated surface competing with the configuration repository; a Dashboard editing feature first, which has none of the fields). Gating fact: deploy clones the configuration repository at `main`, so its `delegated-access` branch is not deployable until merged; either repository can go first because `main` never reads the file and a missing file seeds nothing.
- D10 and D51 stand: one fixture, the `development` section unchanged as the contract.

## Key files

Services: `app/services/delegated_access_seeder.rb`, `app/services/deploy_env_restriction.rb`, `app/services/service_provider_seeder.rb`, `app/services/service_provider_updater.rb`, `app/services/agency_seeder.rb`.
Lib/deploy: `lib/deploy/activate.rb` (`FILES_TO_LINK`), `lib/tasks/delegated_access.rake`, `db/seeds.rb`, `bin/setup`.
Migrations: none new; comments reworded on `20261009100000_add_delegation_content_to_agencies` and `20261009100300_add_delegation_service_provider_columns_to_service_providers` (the stack was rebased so every branch carries them).
Specs: `spec/services/delegated_access_seeder_spec.rb` (absent file, dangling symlink, missing section, `production` section in a sandbox and in `prod`/`staging`, agency restriction, idempotence, environment hosts, the reference-application contract), `spec/services/service_provider_seeder_spec.rb`, `spec/services/agency_seeder_spec.rb`, `spec/lib/deploy/activate_spec.rb`.
Config: `config/delegated_access.localdev.yml`, `.gitignore`, `.gitlab-ci.yml`, `dockerfiles/idp_review_app.Dockerfile`.

## Commits

- `3a50ac249b` FR-ONB-9: delegated-access content seeds from config/delegated_access.yml in every environment

## How to review

Diff against `delegated-access-fraud-signals`. Check first: `DeployEnvRestriction` against the inline rule it replaces (the seeder spec and `service_provider_seeder_spec.rb` must agree), the seeder's handling of a missing file and of `restrict_to_deploy_env`, and that the `development` section of the fixture is unchanged (the harness contract). Then read the companion repository's `delegated_access.yml` and `spec/delegated_access_config_spec.rb` (8 examples on the file's shape). Specs: the seeder spec (56 examples), the service provider and agency seeder specs, the activate spec. Must not change for existing clients: `service_providers.yml` and `agencies.yml` seeding is unchanged; a deploy without `delegated_access.yml` on the configuration repository's `main` seeds nothing new and raises nothing.

## Known open items and later amendments

- Companion repository: the pre-existing "has no invalid logos" example in `spec/service_provider_config_spec.rb` fails until it also counts the logos `delegated_access.yml` references; the product owner decided on 2026-10-10 to leave it unchanged for now. 24 Dependabot alerts there have a conservative fix on branch `update-deps` awaiting that repository's owners (plan section 6 item 13).
- The Dashboard remains the longer-term content path (plan 6.2); when it gains the fields, `ServiceProviderUpdater` already writes them.
- Held until the harness run (plan 6.1): `DelegatedAccessSeeder` reusing `AgencySeeder#write_agency`; the resource-server upsert shared by seeder and updater.

## Depends on / depended on by

Depends on `delegated-access-registry` (the seeder and the records it writes) and, by position, on `delegated-access-fraud-signals`. Depended on by nothing; it is the top of the stack and the pointer `delegated-access-integration` names it.
