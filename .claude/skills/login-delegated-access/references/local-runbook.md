# Local runbook: running the delegated-access stack on one machine

Four processes make up the local stack. Each line says which repository it belongs to.

| Actor | Repository (worktree) | URL |
|---|---|---|
| Login.gov identity provider | `identity-idp`, top-of-stack worktree | http://localhost:3000 |
| Service provider, MyBenefits Assistant (browser public client) | `identity-sts-sinatra` | http://localhost:9292 |
| OIDC agency, Housing Assistance Records API | `identity-oidc-sinatra`, branch `login-delegated-access` | http://localhost:9393 |
| SAML agency, Retirement Benefits Portal API | `identity-saml-sinatra`, branch `login-delegated-access` | http://localhost:4567 |

The contract between them is the `development` section of identity-idp's
`config/delegated_access.localdev.yml` (issuers, resource identifiers, scope values, redirect
URIs, hosts). Change it only together with the apps and the harness.

## Prerequisites

Ruby (version in `.ruby-version`), Node (`.nvmrc`), PostgreSQL and Redis running locally,
Chrome for the browser harness. The reference apps' READMEs list the Homebrew packages.

## identity-idp: fresh worktree checklist (CLAUDE.md section 4)

Run in the worktree the IdP will serve from (the top of the stack):

1. `bin/setup`, or by hand: symlink every `config/*.localdev.yml` to `config/*.yml`, including
   `config/delegated_access.localdev.yml` -> `config/delegated_access.yml`; symlink
   `keys` -> `keys.example`; symlink `pwned_passwords/pwned_passwords.txt` from the sample.
2. `certs`: `bin/setup` links `certs` -> `certs.example`. For delegated access make `certs` a
   real directory instead (copy `certs.example` to `certs`; `/certs` is gitignored), because the
   records agency's certificate is added there and must never land in `certs.example`.
3. Copy `config/application.yml` (gitignored) from a sibling worktree, or create it; see the
   keys below.
4. `mkdir -p tmp/pids`; `npm ci && NODE_ENV=development npm run build && npm run build:css`
   (a production build digests pack names and breaks a layout spec).
5. `bin/rake db:create db:schema:load` for development and test if the databases do not exist;
   worktrees share the development and test databases and Redis.

## identity-idp: development `config/application.yml` keys

All of these are per-developer and gitignored. Key names only; the values are not secrets but
some are placeholders the local contract defines.

| Key | Why |
|---|---|
| `token_exchange_enabled: true` | Master switch; `false` in `application.yml.default` everywhere. Without it discovery advertises nothing and the token-exchange, introspection and revocation endpoints answer as if the feature did not exist. |
| `attempts_api_enabled: true`, `allowed_attempts_providers` | The two agency apps poll the Attempts API in the agency role with the placeholder credentials of the local contract; the agency entries must match the apps' `.env`. |
| `otp_delivery_blocklist_maxretry`, `short_term_phone_otp_max_attempts` | Raised so the harness's back-to-back sign-ins do not trip the one-time-code limiters. Local only. |
| `test:` `redis_*_url` | Optional: separate Redis database numbers so a sibling worktree's spec `flushdb` does not hit this one. |

`token_exchange_attempts_delivery_enabled` defaults to `true` and needs no entry.

## identity-idp: the records agency's certificate

The OIDC agency app generates its own key pair (`make setup` in `identity-oidc-sinatra` writes
`config/rs_demo.key` and `config/rs_demo.crt`; `make rs_cert` prints the PEM). The fixture names
that certificate `rs_records_demo`, so copy `config/rs_demo.crt` to identity-idp
`certs/sp/rs_records_demo.crt`. The seeder copies the PEM into the service-provider row and skips
a name whose file is absent, so re-seed after adding the file. `sp_sinatra_demo.crt` (the SAML
agency) already ships in `certs.example/sp`.

## identity-idp: seeding

`bin/rake db:seed` loads service providers, agencies and the delegated-access content;
`bin/rake delegated_access:seed` reloads only the delegated-access file. `bin/rake dev:prime`
creates the development users; the identity-verified one is `test2@test.com` (the password is
printed by, and documented with, `dev:prime`). Re-seed after changing the fixture or adding a
certificate file.

## The three apps: setup

In each app worktree: `make setup` (creates `.env` from `.env.example`, `bundle install`,
`npm install`, and `make copy_vendor`, which copies the design-system assets to
`public/vendor/identity-design-system`; without it pages render unstyled). Nothing in the
`.env` files is secret except the agency apps' Attempts placeholders, which are the local
contract's values. The agency apps' default `CORS_ALLOWED_ORIGINS` is `http://localhost:9292`.

## Starting and stopping: `scripts/local_stack.sh`

```
scripts/local_stack.sh up       # IdP (:3000) + good_job, and the apps on :9292, :9393, :4567
scripts/local_stack.sh status   # ports, listener PIDs, which ones this script started
scripts/local_stack.sh check    # discovery, config.json and the three roots
scripts/local_stack.sh down     # stops only the PIDs it recorded
```

Worktree paths come from `IDP_DIR` (default: the repository the skill lives in), `SP_DIR`,
`OIDC_AGENCY_DIR`, `SAML_AGENCY_DIR` (defaults under `~/coding/worktrees/`). PIDs and logs go to
`tmp/local_stack/` in the skill's repository. `up` refuses to start when a port is busy and says
who owns it; it checks prerequisites and prints instructions rather than fixing anything (no
seeding, no git, no copying). The IdP runs with `LAUNCHY_DRY_RUN=true` so development emails do
not open in a browser; letter_opener still writes them to `tmp/letter_opener/`. Puma renames its
process title to `puma ... (tcp://localhost:PORT) [dir]`, so identify servers by port, not by
command name. Sinatra does not reload: restart an app after pulling.

## Verifying

- `curl -s http://localhost:3000/.well-known/openid-configuration`: `grant_types_supported`
  lists `refresh_token` and `urn:ietf:params:oauth:grant-type:token-exchange`;
  `introspection_endpoint` and `revocation_endpoint` are present. If not, the switch is off or
  the IdP is serving from a worktree with another `application.yml`.
- `curl -s http://localhost:9292/config.json`: `idp_url` is `http://localhost:3000` and the two
  `resources` entries carry `https://records-api.agency.localdev` (url `http://localhost:9393/records`)
  and `https://benefits-api.agency.localdev` (url `http://localhost:4567/api/benefits`). These
  must agree with the fixture's `development` section.
- `http://localhost:9393/api/health` reports the discovered `introspection_endpoint`.

## Signing in by hand

Open http://localhost:9292, choose the identity-verified level, tick one or both applications,
sign in as `test2@test.com`. The one-time code is pre-filled in development. A first sign-in
also asks to accept the rules of use and shows the second-MFA reminder ("Continue to ...").
Approve on the completion screen; the dashboard then exchanges, calls, refreshes and revokes per
application. The user's own view is http://localhost:3000/account/delegated_access; the agencies'
decision logs are `/decisions` on :9393 and :4567.

## Running the harness (in the service provider worktree)

```
E2E_IDP_URL=http://localhost:3000 E2E_USER_EMAIL=test2@test.com bundle exec rspec spec/e2e
```

Expected: 21 examples, 0 failures, 1 pending (the expiry scenario behind
`E2E_WAIT_FOR_EXPIRY`). `E2E_USER_PASSWORD` defaults to the `dev:prime` password;
`E2E_HEADLESS=false` shows the browser. Before a run, stop leftover headless Chrome and
chromedriver processes from an earlier aborted run (`pgrep -fl "chromedriver|--headless"` to see
them; stop only those). Each scenario empties the IdP's Attempts store first.

## identity-idp browser specs while the stack is up

Capybara-webmock proxies through port 9292, which the service provider occupies. Run browser
specs with a one-off file outside the repository, for example `rspec -r /tmp/webmock_port.rb`
containing `Capybara::Webmock.port_number = 19292` (any free port). Never run two rspec
processes in one worktree; prefer a dedicated test database when sibling worktrees run specs.

## Common failures

| Symptom | Where | Fix |
|---|---|---|
| Pages render unstyled | any app | `make copy_vendor` in that app (or `make setup`). |
| Records API answers 503 | OIDC agency | Introspection failed: the IdP has no `rs_records_demo` certificate on the agency's row. Copy the cert into `certs/sp/`, `rake delegated_access:seed`, restart nothing. Also 503 when discovery has no `introspection_endpoint` (switch off). |
| `consent_required` or an unexpected consent page in one scenario | IdP | Remembered approvals left by a previous run for `test2@test.com`; revoke them at `/account/delegated_access` or end all delegated access there, then rerun. |
| Browser stuck at `about:blank`, "Node with given id does not belong to the document" | harness | Leaked headless Chrome from an aborted run; stop those processes and rerun. |
| `PendingMigrationError` or a column missing in development | IdP | Schema drift from a sibling worktree on the shared development database; `bin/rake db:migrate` from the top of the stack. |
| "Failed to fetch" on an API call | agency app | CORS preflight refused; `CORS_ALLOWED_ORIGINS` must include `http://localhost:9292`. |
| `invalid_scope` back at the service provider | IdP | Application not registered or inactive; re-seed. |
| `invalid_dpop_proof` at the code exchange | service provider | Two sign-ins in two tabs share IndexedDB; use one tab. |
| "Account temporarily locked" after many sign-ins | IdP | One-time-code limiter; raise the two keys above or wait. |
| Port busy at `up` | script | Another process owns the port; `status` shows it. Stop it yourself only if it is yours. |
