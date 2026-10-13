# Sandbox notes: what changes between a developer machine and a sandbox

Source: `docs/delegated-access-functional-requirements.md` section 13 and Appendix C. A sandbox is a
personal environment or `dev`/`int`: `RAILS_ENV=production` with a deploy environment other
than `prod` or `staging`, so entries restricted to `sandbox` are written and `prod`/`staging`
entries are not.

## Content and hosts

- Locally `config/delegated_access.yml` is a link to the fixture
  `config/delegated_access.localdev.yml`. In a sandbox `deploy/activate` links
  `<identity-idp-config checkout>/delegated_access.yml` instead (`Deploy::Activate::FILES_TO_LINK`),
  and `rake db:seed` seeds it. The configuration repository is cloned at `main`, so content on its
  `delegated-access` branch reaches no sandbox until merged.
- Two ways to point the content at hosted reference applications:
  1. The fixture's `production:` section (every entry `restrict_to_deploy_env: 'sandbox'`) with
     `DELEGATION_SP_URL`, `DELEGATION_OIDC_AGENCY_URL` and `DELEGATION_SAML_AGENCY_URL` set in the
     seed task's environment; the file is run through ERB before loading.
  2. The configuration repository's `delegated_access.yml` with the hosts written in and every
     fictitious entry carrying `restrict_to_deploy_env: 'sandbox'`.
- The RFC 8707 resource identifiers (`https://records-api.agency.localdev`,
  `https://benefits-api.agency.localdev`) and scope values never change with the host; only
  redirect URIs, `return_to_sp_url`, `acs_url`, the learn-more URLs and the apps' `/config.json`
  hosts do. The IdP's registered redirect URIs and the service provider's published hosts must
  agree, or the browser client's CORS origin check and its redirect fail.

## Certificates

- Locally the seeder reads `certs/sp/<name>.crt` and skips absent names. A sandbox either ships
  the file in `identity-idp-config/certs/sp` (linked to `certs/sp` by `deploy/activate`) or
  pastes an inline PEM string in the `certs:` entry. The hosted agency apps must hold the matching
  private keys.

## Application configuration

- `token_exchange_enabled: true` goes in the sandbox's app-secrets `application.yml`; it is
  `false` by default everywhere. `token_exchange_attempts_delivery_enabled` defaults to `true`.
- Attempts: the agencies' `allowed_attempts_providers` entries and `attempts_api_enabled` are set
  per environment with that environment's credentials; delivery reaches only an agency enrolled
  there with a usable key.
- `document_images_sharing_enabled` and `document_images_sharing_service_providers` are on in
  the sandbox only (D49) and stay at their defaults elsewhere.
- The OTP limiter keys raised locally for the harness are not needed in a sandbox unless the
  harness runs against it.

## Logos

- The three fictitious logos live in `identity-idp-config` `public/assets/images/sp-logos/` and
  are referenced by the sandbox-restricted entries; the local fixture uses `generic.svg`.

## Nothing to remove

- The `Rack::Cors` rules for `/api/openid_connect/token`, `/revoke` and `/introspect` are
  production behavior for a browser public client; origins come from registered redirect URIs.
- Discovery is gated by `token_exchange_enabled`, not by environment.
- The reference apps need only environment variables (`idp_url`, hosts, `CORS_ALLOWED_ORIGINS`,
  key paths); no code changes.

## Getting the stack onto a sandbox

Two routes exist; the choice follows what the feature needs to exercise.

- **A Chef-managed personal sandbox** (the `agroot` model already named for `allow_unsafe_migrations`
  in `identity-devops` `kitchen/environments/`). Full fidelity: real hosts, workers, Redis, S3, the
  Attempts API's S3 storage, scheduled reports and a real `identity-idp-config` checkout. The deploy
  resolves the branch by name from GitHub, so the branch must be on GitHub first (the GitLab mirror
  overwrites diverged branches). `deploy/activate` deep-merges the environment's `application.yml`
  and clones `identity-idp-config` at `main`, which is why a config-repo branch is never deployable
  and sandbox content rides in on the fixture instead.
- **A GitLab review app** (any non-`main` branch pipeline on the `lg/identity-idp` mirror). No worker
  processes and no scheduled reports, but enough for the browser flows, the exchange, introspection
  and revocation. This is the lighter first-run route; use the Chef environment when a feature needs
  workers or report output (fraud-signal delivery, billing reports).

What the branch must get right so either route boots without an `application.yml` change:

- Every new configuration key has a safe default in `application.yml.default`, so the feature is off
  until its switch is turned on (`token_exchange_enabled`, `token_exchange_attempts_delivery_enabled`).
- A seeding path independent of `identity-idp-config`: `rake db:seed` reads the fixture (linked to
  `config/delegated_access.yml`), so a sandbox gets the fictitious actors without the shared config
  repo carrying keys `main` does not know. Resource-server certificates live in the database, loaded
  from the fixture, not on disk.
- An identity-verified test user for the harness (`E2E_USER_EMAIL`); both routes use the mock
  document-authentication vendor, so one can be proofed without live vendors.
- The new public paths `/api/openid_connect/introspect` and `/api/openid_connect/revoke` are under
  the existing `/api/openid_connect/` prefix; confirm the edge/WAF rules admit them.
- Redis is already provisioned: the client-assertion and DPoP `jti` caches, the Attempts buffer and
  the billing-correlation cache all use the existing `REDIS_POOL`; nothing new to stand up.
