# The foundation: branch `sbx-taigrr`

Source: `docs/delegated-access-implementation-plan.md` section 3 (3.1 components, 3.3 collisions, 3.4 kept pieces), section 4 (approach) and the "Remove, and why" lists of each 5.x section. Branch reviewed at `0b0539e19` (15 commits, 91 files, about 6,200 lines added, 206 spec examples).

## What it is

`sbx-taigrr` is the branch `login-delegated-access` starts from: `main` at `827da132a` plus the `token-exchange` branch (an RFC 8693 exchange with target opt-in, per-application grants and account-page toggles) merged with `proofing/socure-identity-artifacts` (identity-document image and metadata sharing). The base branch is `sbx-taigrr` with `main` merged (plan section 2) and the three documents under `docs/`; every feature branch is stacked on that.

Its design is not a partial implementation of the functional requirements; it answers a different question, which is why the stack layers a new architecture on top of it (ported by hand from `token-exchange2-login`, never merged) rather than finishing it.

## Components (plan 3.1)

1. `POST /api/openid_connect/exchange` (`OpenidConnect::ExchangeController`, `OpenidConnectTokenExchangeForm`) with a `Rack::Cors` rule in `config/application.rb` so browsers can call it.
2. A bare `token_exchange` scope, honored only for service providers listed in the `token_exchange_service_providers` JSON key of `application.yml`, treated as an IAL2 attribute scope so it flows through `requested_attributes`.
3. Target opt-in: `service_providers.allowed_token_exchange_brokers` (string array).
4. `token_exchange_grants` (user, broker issuer, target issuer; 12-month expiry; revoke-not-delete) and `token_exchange_broker_settings` (auto-enrollment of future targets).
5. Consent on the existing completions screen: "allow across all linked agencies", "automatically enroll new agencies", or pick specific linked applications grouped by agency.
6. Account page: per-application on/off toggles and an auto-enroll toggle under the service provider's connected-app entry, with a confirmation modal.
7. Billing: an `SpReturnLog` row for the target at mint, billable once per (user, target, service provider session) through a deterministic `request_id`.
8. Attempts API: one `token-exchange-login-completed` event to the target at mint, carrying `broker_issuer`.
9. `id_token` for the target with an RFC 8693 `act` claim naming the service provider; no `nonce`, no `c_hash`.
10. `document_images` scope, `document_artifacts` and `document_metadata` tables, `GET /api/openid_connect/document_images/:type` bearer download, biometric consent checkbox, `ExpireDocumentArtifactsJob`, two design documents under `docs/proofing/`.

## How it differs from the requirements

- **Browser-callable exchange with no client secret.** The requirements put the exchange at the existing token endpoint with client handling by client type (`private_key_jwt` for confidential clients, `client_id` plus a DPoP proof for the public client). The separate route and its CORS entry add surface for nothing (FR-TOK-1, FR-TOK-2).
- **A full user access token for the target.** The foundation mints through `IdentityLinker` against the target service provider, so the target appears in connected services as if the person had signed in there, a later direct sign-in skips its consent screen, the token works at userinfo, and an `id_token` is returned to the caller (FR-TOK-6, FR-CEN-12 violated). The requirements issue an opaque reference the agency verifies by introspection; nothing is created at the agency.
- **Consent per connected application.** The screen lists the applications the person has already connected that opted in to the caller; the request names no target, so Login.gov cannot refuse an unknown one at authorize (FR-CEN-1, FR-CEN-2). The requirements name applications in the request (`token_exchange:<scope value>`) and define reach by the registry.
- **Lifetime is the caller's Rails session**, with no refresh, no revocation endpoint and no cascade (FR-TOK-10 to FR-TOK-16 missing).
- **Vocabulary.** The code calls the service provider the "broker"; the project says *service provider* (plan 4.5).

## Kept and generalized (plan 3.4)

1. **Agency opt-in to specific service providers.** `allowed_token_exchange_brokers` becomes `allowed_delegation_service_providers` on the application row (empty means any approved service provider), enforced at authorize and at exchange (FR-CEN-2; D7). Registry branch.
2. **IAL forwarded, never elevated** (FR-FIT-5): `ial` and `aal` copied onto the delegated token. Token-exchange branch.
3. **The `act` claim naming the service provider** (FR-VER-3): moves from the target `id_token` to the introspection response (`act: {sub: <issuer>}`) and the SAML `actor` attribute. Introspection and SAML branches.
4. **Analytics on every decision** (FR-OPS-2), renamed to the new vocabulary; `openid_connect_token_exchange` keeps its name with new properties.
5. **No target-side error until the caller has cleared its own gates** (audience probing): the exchange form validates client, request shape, subject token and proof before it says anything about the registry or approvals; `consent_required` is given only to an authenticated caller for a registered resource (D31).
6. **Document image and metadata sharing for a direct service provider** (plan 5.12): kept on the base behind `document_images_sharing_enabled`, on in the sandbox only (D49). Not a branch.
7. **mDL exemption** for image sharing (`SocureImageRetrievalJob` skips mDL sessions); compatible with `main`'s own mDL early return (plan section 2).
8. **Per-application toggles on the account page**: the pattern (one control per application under the service provider, confirmation before approving) is kept; the population becomes every registered application that accepts the service provider, not the ones the person connected to (D4, D23).
9. **One consent choice per application, grouped by agency**: the foundation's screen already works at application granularity, which is the decided granularity (D1).

## Removed or replaced, and by which branch

| Foundation piece | Fate | Branch |
|---|---|---|
| `token_exchange_grants` (user, broker, target) and `token_exchange_broker_settings` | One migration drops both and creates the (user, service provider issuer, application) grant; auto-enrollment conflicts with the registry-defined list (D4, D8) | `delegated-access-registry` (`20261009100400_replace_token_exchange_grants`) |
| `allowed_token_exchange_brokers` | Replaced by `allowed_delegation_service_providers` (D7) | `delegated-access-registry` |
| `token_exchange_service_providers` allow-list in `application.yml` | Replaced by `service_providers.token_exchange_enabled_sp`; `token_exchange_enabled` stays the master switch (D7, FR-ONB-9) | `delegated-access-registry` |
| Two localdev fixtures `…:sp:token_exchange_broker` and `…:token_exchange_target` | Replaced by `config/delegated_access.localdev.yml` and the seed task | `delegated-access-registry` |
| `docs/token-exchange.md` | Removed; it describes the superseded design | `delegated-access-registry` |
| "Broker" in identifiers, strings, comments, analytics, locale keys; browser-callable and public-client-of-Login.gov comments | Full terminology sweep, including code later branches delete (D11; ONB-14) | `delegated-access-registry` |
| Bare `token_exchange` attribute scope in `OpenidConnectAttributeScoper` | Removed; it names no application and its presence in `verified_attributes` skipped the screen for a year. Replaced by `token_exchange:*` values that never enter `verified_attributes` | `delegated-access-consent` |
| "Allow all linked" / "auto-enroll" controls, `_token_exchange_grant.html.erb`, its TypeScript pack, `TokenExchangeReachableTargets.linked_for`, `record_token_exchange_decision` | Replaced by locked requested rows and `TokenExchangeConsent` (D5) | `delegated-access-consent` |
| `sign_up.token_exchange_grant.*` locale keys | Replaced by `sign_up.delegation.*` | `delegated-access-consent` |
| Inline account toggles (`_token_exchange_manage.html.erb`, `TokenExchangeGrantsController`, `account.connected_apps.token_exchange.*`) | Replaced by Account → Delegated access (D19 to D23) | `delegated-access-account-page` |
| `OpenidConnect::ExchangeController`, `/api/openid_connect/exchange` routes and CORS rule | Exchange moves to the token endpoint (RFC 8693 §2.1) | `delegated-access-token-exchange` |
| Minting through `IdentityLinker` against the target; `IdTokenBuilder` `actor:` and the `act` id_token claim; `target_in_use`; claim-space narrowing (`BUNDLE_ATTRIBUTE_TO_CLAIM`, `target_scope`) | Replaced by `TokenExchangeToken` and `DelegatedTokenStore`; builder reverted to `main`'s shape | `delegated-access-token-exchange` |
| `bill_target` and `billing_request_id` keyed to the browser session | Replaced by `Billing::DelegatedReturnRecorder` keyed to the approval (`tx:<delegation_id>:<billing issuer>:<ial>`) | `delegated-access-billing-reporting` |
| `token-exchange-login-completed` Attempts event and its schema | Replaced by `delegated-access-token-issued` and the delegated event family with `delegation_id` | `delegated-access-fraud-signals` |

## Name collisions resolved deliberately (plan 3.3)

The same name meant different things on `sbx-taigrr` and `token-exchange2-login`; each is resolved inside the branch that owns the new meaning, with no shim keeping both alive.

1. Table `token_exchange_grants`: decided shape is one live row per (user, service provider, application), closer to the foundation's key with new columns (D8). Dropped and recreated.
2. Classes `TokenExchangeGrant` and `OpenidConnectTokenExchangeForm`: same names, new bodies; the foundation spec files are replaced, not merged.
3. Scope string: bare `token_exchange` versus `token_exchange:<value>`; the bare value goes.
4. Config key `token_exchange_enabled`: same meaning on both. Kept.
5. Config key `token_exchange_service_providers` versus column `token_exchange_enabled_sp`: the column wins (ONB-5).
6. Analytics event `openid_connect_token_exchange`: same name, the new form's properties.
7. Attempts event `token-exchange-login-completed` versus the `delegated-access-*` family: the family wins.
8. Locale keys `sign_up.token_exchange_grant.*` / `account.connected_apps.token_exchange.*` versus `sign_up.delegation.*` / `account.delegated_access.*`.
9. `ServiceProvider#token_exchange_broker_allowed?` / `#allows_token_exchange_broker?` versus `#delegation_service_provider?` / `#accepts_delegation_from?`.

## Why this matters when you change things

- **Nothing is kept for compatibility.** Neither branch was in production, so the sandbox database held the foundation's tables and the registry migration drops them. Do not add `legacy`/`old` variants or flags for foundation behavior (plan 4.7).
- **Refusing null bytes on every lookup by untrusted value** (the foundation's `db_safe?` habit, plan 5.4 Findings 4) is kept as inline checks: `TokenExchangeRefreshToken.lookup`, the exchange form's `subject_token` check, and the revoke and introspect forms' `token` checks. Keep it on any new lookup.
- **Target-side errors stay hidden until authentication**: the validation order of `OpenidConnectTokenExchangeForm`, and `{"active": false}` from introspection for anyone but the audience or bound holder (D62), are the foundation's audience-probing rule generalized. Preserve the order when adding checks.
- **Delegated tokens are refused at userinfo** because they are never `identities` rows; the foundation's channel was exactly that row. `AccessTokenVerifier#load_identity` says so in a comment; do not add a second lookup path.
- **Document images stay reachable only through a direct sign-in** (INT-16, DOC-1). A delegated token never sets `biometric_sharing_consent_at`, so the artifact store is unreachable by delegation; keep it that way.
- **Agency opt-in and IAL forwarding** are foundation decisions now enforced in two places each (authorize and exchange; exchange and refresh). A change to either must land in both.
- **Analytics keep the foundation's event name** `openid_connect_token_exchange`; dashboards built on the sandbox keyed on that name still work, with new properties.
- **The `act` fact moved** from a token the caller could read to the introspection response and SAML attribute the agency reads; do not reintroduce it into anything the service provider receives.
