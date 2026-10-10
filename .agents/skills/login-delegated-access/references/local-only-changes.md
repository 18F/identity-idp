# Inventory of local-only and sandbox-only pieces

The authoritative list is the table in `docs/delegated-access-implementation-plan.md`
section 7.5 ("Environment-specific pieces and how to remove them"); CLAUDE.md section 6 says to
add to that table whenever a new local-only piece is introduced. This file is the developer-facing
mirror with exact locations, so each piece can be found, removed or disabled deliberately.
`scripts/local_only_changes.sh` prints the current `file:line` hits for comparison.

Scope legend: **local** = developer machine, CI and review apps; **sandbox** = a personal sandbox
or `dev`/`int` (`RAILS_ENV=production`, deploy environment not `prod`/`staging`); **not
environment-specific** = production behavior that looks local because it names localhost or a
switch.

## identity-idp

| Piece | Location | What it does | Scope | How to remove or disable |
|---|---|---|---|---|
| Delegated-access fixture | `config/delegated_access.localdev.yml`; `development:` section (line 46), `production:` section (line 185); hosts via `ENV.fetch("DELEGATION_SP_URL" ...)`, `DELEGATION_OIDC_AGENCY_URL`, `DELEGATION_SAML_AGENCY_URL` (lines 54, 61, 68, 82-86, 108-112, 152-154 and again under `production`) | Agencies, the service provider and the two applications with their APIs, keyed by Rails environment; `development` is the contract with the three apps and the harness | local (`development`), sandbox (`production` entries all carry `restrict_to_deploy_env: 'sandbox'`, lines 188-276) | Nothing to disable: deployed environments link `identity-idp-config/delegated_access.yml` instead, and `prod`/`staging` write no `sandbox` entry. Edit only together with the apps. |
| Link of the fixture | `bin/setup` line 37 (`test -r config/delegated_access.yml \|\| ln -sv delegated_access.localdev.yml ...`); `.gitignore` line 48 (`/config/delegated_access.yml`) | Puts the fixture where `DelegatedAccessSeeder` reads | local | Same pattern as `agencies.yml`; leave. In a deployed environment `lib/deploy/activate.rb` `FILES_TO_LINK` (line 10) links the configuration repository's file instead, which is production behavior. |
| Seeder entry points | `db/seeds.rb` (`DelegatedAccessSeeder` after `AgencySeeder`); `lib/tasks/delegated_access.rake` (`rake delegated_access:seed`) | `db:seed` loads the file in every environment; the rake task reloads it alone | not environment-specific (runs everywhere; a missing file seeds nothing) | Nothing; the task is a convenience only. |
| Review-app and CI copies of the fixture | `dockerfiles/idp_review_app.Dockerfile` line 131 (`COPY ... config/delegated_access.localdev.yml ... config/delegated_access.yml`); `.gitlab-ci.yml` line 297 (`cp config/delegated_access{.localdev,}.yml`) | Review apps and CI seed the fictitious content | local (review apps, CI) | Remove the two lines together with the fixture if review apps should hold no fictitious content. |
| Development `config/application.yml` | gitignored, per developer; keys `token_exchange_enabled`, `attempts_api_enabled`, `allowed_attempts_providers`, `otp_delivery_blocklist_maxretry`, `short_term_phone_otp_max_attempts`, optional `test:` `redis_*_url` | Turns the capability on, enrolls the two agencies in the Attempts API with the local contract's placeholders, relaxes OTP limits for the harness | local; the sandbox sets `token_exchange_enabled` and the agency Attempts entries in its app-secrets file | Leave the keys at `config/application.yml.default` values (`token_exchange_enabled: false`, `allowed_attempts_providers: '[]'`): discovery advertises nothing, the endpoints answer not found. |
| Sample certificate names | fixture `certs:` entries `rs_records_demo` (lines 114, 143, 251, 273) and `sp_sinatra_demo` (lines 157, 181, 286, 308); files `certs/sp/rs_records_demo.crt` (developer-supplied, under gitignored `/certs`), `certs.example/sp/sp_sinatra_demo.crt` (tracked sample) | Agency keys for introspection assertions and SAML assertion encryption | local; a sandbox pastes an inline PEM or ships the file in `identity-idp-config/certs/sp` | The seeder reads `certs/sp/<name>.crt` only when present and skips it otherwise; nothing to remove where the file is absent. |
| Capybara-webmock port workaround | `spec/support/capybara.rb` lines 31 and 55 (`--proxy-server=127.0.0.1:#{Capybara::Webmock.port_number}`); the override lives in a file outside the repository passed with `rspec -r` | Lets browser specs run while the service provider holds :9292 | local | Nothing in the repository to remove. |
| Fictitious application logos | `identity-idp-config` (branch `delegated-access`) `public/assets/images/sp-logos/mybenefits-assistant.svg`, `housing-assistance-records.svg`, `retirement-benefits-portal.svg`, referenced by `logo:` in that repository's `delegated_access.yml`; the identity-idp fixture uses `logo: 'generic.svg'` only | Logos for the sandbox demo | sandbox | Delete the three files with the fictitious entries when real content replaces them; `delegated_access_config_spec.rb` there checks every referenced logo exists. |
| `allow_unsafe_migrations: true` | `identity-devops` `kitchen/environments/agroot.json` | Property of that sandbox | sandbox | Not part of this branch. |

### Not environment-specific although it looks it

| Piece | Location | Why it stays |
|---|---|---|
| `Rack::Cors` rules for `/api/openid_connect/token`, `/revoke`, `/introspect` (`credentials: true`, `post options`) | `config/application.rb` lines 143-170; origins decided by `lib/identity_cors.rb` `allowed_redirect_uri?` (registered redirect URIs) | A browser public client calls these endpoints cross-origin in production too (D59). The localhost origins come from the registered redirect URIs, not from a hard-coded list. |
| Discovery metadata for the exchange grant, introspection and revocation | `app/presenters/openid_connect_configuration_presenter.rb` line 86 (`IdentityConfig.store.token_exchange_enabled`); endpoint gating in `app/controllers/concerns/openid_connect/delegated_endpoint_concern.rb` line 13 and `app/controllers/openid_connect/token_controller.rb` | Gated by the switch, not by environment (D48). |
| `redis_attempts_api_url` and the other `redis_*_url` keys | `config/application.yml.default` lines 454-461 | Standard per-environment Redis configuration; the local `test:` overrides are a developer convenience only. |
| Alert thresholds | none in the application (removed 2026-10-11) | Written as `identity-devops` alarms over the analytics stream. |

## identity-sts-sinatra (service provider, browser public client)

| Piece | Location | What it does | Scope | How to change |
|---|---|---|---|---|
| Hosts and identifiers | `.env.example` (`redirect_uri=http://localhost:9292/`, `idp_url=http://localhost:3000`, `RESOURCE_SERVER_URL=http://localhost:9393`, `SAML_RESOURCE_SERVER_URL=http://localhost:4567`, `THIRD_PARTY_RETURN_URI`); `config.rb` defaults; published at `/config.json` | Non-secret configuration the browser reads | local defaults; sandbox sets the variables | Set the environment variables; identifiers and scopes are registry facts and never change with the host. `/config.json` must agree with the IdP fixture's hosts. |
| Compose harness | `docker-compose.e2e.yml` (host networking; `IDP_PATH`, `OIDC_RS_PATH`, `SAML_RS_PATH`; sets `LOGIN_TOKEN_EXCHANGE_ENABLED`, runs `delegated_access:seed`) | Brings up all four actors for CI | local/CI | Not used by a deployment. |
| Harness defaults | `spec/e2e/e2e_helper.rb` (`E2E_SP_URL`, `E2E_RS_URL`, `E2E_SAML_RS_URL` default to the localhost ports; `E2E_USER_EMAIL`) | Drives the live stack | local/CI; skipped without `E2E_IDP_URL` | Set the `E2E_*` variables for another host. |
| Design-system assets | `Makefile` `copy_vendor` -> `public/vendor/identity-design-system` (gitignored) | Styling | local build step | Part of the build in any environment. |

## identity-oidc-sinatra (OIDC agency, Housing Assistance Records)

| Piece | Location | What it does | Scope | How to change |
|---|---|---|---|---|
| CORS allowed origins | `config.rb` line 197 (`ENV['CORS_ALLOWED_ORIGINS'] \|\| 'http://localhost:9292'`); `.env.example` `CORS_ALLOWED_ORIGINS`; headers set in `app.rb` around lines 608-624 | Lets the service provider's page call `/records` cross-origin | Default is local; the mechanism is production behavior | Set `CORS_ALLOWED_ORIGINS` to the deployed service provider's origin. Never remove the CORS code. |
| Session cookie name | `app.rb` line 104 (`set :sessions, key: 'records_agency.session'`) | Browsers scope cookies by host, not port, so on localhost a default cookie name collides with the other apps | local convenience; harmless elsewhere | Leave. |
| Hosts | `.env.example` (`redirect_uri=http://localhost:9393/`, `idp_url`, `idp_domain=localhost:3000`) | Direct sign-in and introspection targets | local defaults | Set the variables. |
| Demo key and certificate | `config/rs_demo.key`, `config/rs_demo.crt` (generated by `make setup`, never committed); registered at the IdP as `rs_records_demo` | Introspection assertion and Attempts decryption | local | A sandbox registers its own key through onboarding. |
| Attempts placeholders | `.env.example` `attempts_shared_secret` (the local contract's placeholder, not a secret) | Agency-role Attempts viewer | local | Per-environment credentials from onboarding. |

## identity-saml-sinatra (SAML agency, Retirement Benefits Portal)

| Piece | Location | What it does | Scope | How to change |
|---|---|---|---|---|
| CORS allowed origins | `resource_server_config.rb` lines 119-120 (`ENV.fetch('CORS_ALLOWED_ORIGINS', 'http://localhost:9292')`); headers in `app.rb` around line 620 | Cross-origin `/api/benefits` for the service provider's page | Default is local; the mechanism is production behavior | Set the variable; never remove the code. |
| Session cookie name | `app.rb` line 45 (`Rack::Session::Cookie, key: 'sinatra_sp'`) | Distinct cookie per app on localhost | local convenience | Leave. |
| Hosts | `.env.example` (`assertion_consumer_service_url=http://localhost:4567/consume`, `idp_sso_target_url`, `idp_slo_target_url`, `idp_url`, optional `IDP_METADATA_URL`) | Direct SAML sign-in and metadata | local defaults | Set the variables and the IdP certificate fingerprint for the target environment. |
| Demo key and certificate | `config/demo_sp.key`, `config/demo_sp.crt` (the upstream sample pair, registered at the IdP as `sp_sinatra_demo`) | Assertion decryption and direct sign-in | local | A sandbox registers its own pair. |
