# delegated-access-fraud-signals

## Purpose

Plan 5.7, fraud signals: Attempts API delivery to agencies. While a delegation request is in flight the sign-in session's Attempts events are buffered in the KMS-encrypted part of the session; at consent (or when a remembered approval lets the screen be skipped, or on an account-page approval) they are released to each approved application's enrolled agency under the person's identifier at that agency, with a consented event and the identity-verification history; later session events are forwarded live; token issued, refreshed and revoked events carry `delegation_id`. The foundation sent one `token-exchange-login-completed` event to the target at mint and nothing else.

## Requirements it satisfies

FR-FRD-1 to FR-FRD-9; FR-CEN-13 and FR-TOK-12 (reported to the agency). Companion §8 (ATT-1..18 as amended).

## What it adds / removes and why

Adds:
- `token_exchange_attempts_delivery_enabled` (default `true`, D74); `DelegatedAccessEvents.enabled?` is that key with `token_exchange_enabled` and `attempts_api_enabled`. Per recipient the gate is enrollment: `ServiceProvider#attempts_api_deliverable?` (listed in `allowed_attempts_providers`, an agency, a usable key); `#delegation_attempts_recipients` (each active API's `attempts_recipient`, else the application).
- `AttemptsApi::DelegationContext` at the Rails session root (`delegation_context`, `delegated_attempts_buffer`), started by `OpenidConnect::AuthorizationController#start_delegation_context` when the validated request carries delegation scopes. While `active?`, `AttemptsApi::Tracker#track_event` copies each event into the buffer (`capture_for_delegation`, `user_uuid` and `google_analytics_cookies` removed) without creating an `AgencyIdentity`; capped at `MAX_BUFFERED_EVENTS` (200); listed in `SessionEncryptor::SENSITIVE_PATHS` so it is KMS-encrypted once per save; discarded with the session (FR-FRD-9).
- `AttemptsApi::DelegatedRelease` at three points: `VerifySpAttributesConcern#record_delegation_consent`, `OpenidConnect::AuthorizationController#release_remembered_delegation` before `login-completed` is recorded, and `Accounts::DelegatedAccess::ApprovalsController#create`. For each deliverable recipient it creates the `AgencyIdentity` if missing (never an `identities` row), forwards the buffer once per recipient per session, writes one `delegated-access-consented` event per approval, releases the `idv-*` history under `AttemptsApi::HistoricalReleaseCheck` (extracted from `Idv::HistoricalAttemptsConcern`), and marks the recipient for live fan-out only when the current sign-in is to that service provider (D66). Released once per SP request id (`mark_released`/`released_for?`, D67). Failures are reported and never block the person.
- `AttemptsApi::DelegatedEventWriter` includes `AttemptsApi::TrackerEvents`: a forwarded copy keeps the event, replaces `user_uuid`, adds `delegation_id` and `actor_issuer`; a server-side event (consent, token, revocation) carries no IP, user agent or device. Both encrypt to the recipient's key and store through `AttemptsApi::RedisClient#write_event`, so the agency polls the existing endpoint. Logged as `delegated_access_attempts_delivery`.
- `DelegatedAccessEvents.token_issued` (from `#issue!`), `.token_refreshed` (from the refresh form) and `.access_revoked` (from `TokenExchangeGrant#revoke!` and `TokenExchangeRefreshToken.revoke_family!`, so reuse, lapse and client revocation each tell the one API's agency once). Events are `delegated-access-consented`, `-token-issued`, `-token-refreshed`, `-revoked`; `superseded_by_new_consent` is never reported (E97).
- Schemas: `docs/attempts-api/schemas/events/DelegationEvents.yml`, the four files under `events/delegated-access/`, `actor_issuer` and `delegation_id` in `shared/EventProperties.yml`, the compiled bundle rebuilt (ATT-16).

Removes: the `token_exchange_login_completed` tracker event, its schema and method: it reported a sign-in at the target, which never happens now. Its opaque-session-id and no-network-details choices are kept.

## Key decisions

- D33 reuse reports `refresh_token_reuse` to the one API's recipient; D38 the full plan stands; D39 a remembered approval reused sends that sign-in's events and a consent event marked remembered, every time.
- D66 account-page approvals release but start live fan-out only for the current service provider (rejected: forwarding the account session's events to a merely pre-approved agency); D67 released-once keyed by SP request id (rejected: a per-session flag).
- D74 delivery on by default, gated per recipient by enrollment (rejected: default off until the privacy review); D58 the agency-role viewer is `identity-oidc-sinatra`'s.

## Key files

Models: `app/models/service_provider.rb` (`attempts_api_deliverable?`, `delegation_attempts_recipients`), `app/models/token_exchange_grant.rb`, `app/models/token_exchange_refresh_token.rb`.
Forms: `app/forms/openid_connect_token_exchange_form.rb`, `app/forms/openid_connect_refresh_token_form.rb`.
Services: `app/services/attempts_api/{delegation_context,delegated_release,delegated_event_writer,historical_release_check}.rb`, `app/services/attempts_api/{tracker,tracker_events,attempt_event,historical_attempt_event}.rb`, `app/services/delegated_access_events.rb`, `app/services/analytics_events.rb`.
Controllers: `app/controllers/openid_connect/authorization_controller.rb`, `app/controllers/concerns/verify_sp_attributes_concern.rb`, `app/controllers/concerns/idv/historical_attempts_concern.rb`, `app/controllers/accounts/delegated_access/approvals_controller.rb`.
Migrations: none.
Specs: `spec/services/attempts_api/{delegation_context,delegated_release,delegated_event_writer,historical_release_check,tracker}_spec.rb`, `spec/services/delegated_access_events_spec.rb`, `spec/controllers/openid_connect/authorization_controller_spec.rb`, `spec/controllers/sign_up/completions_controller_spec.rb`, `spec/controllers/accounts/delegated_access/approvals_controller_spec.rb`, the service provider, grant and refresh token model specs, `spec/requests/openid_connect/{token_exchange,token_refresh}_spec.rb`.
Config/docs: `lib/identity_config.rb` and `config/application.yml.default` (`token_exchange_attempts_delivery_enabled`), `lib/session_encryptor.rb`, `docs/attempts-api/schemas/**`, `docs/attempts-api/compiled-api.yml` (machine-read; not prose).

## Commits

- `15bc944122` FR-FRD-1, FR-FRD-8, FR-FRD-9: buffer the sign-in session's Attempts events while a delegation request is in flight
- `296fe2b4a9` FR-FRD-4: forward later session events to approved agencies as they happen
- `ab1e9d03fb` FR-FRD-2, FR-FRD-3, FR-FRD-7: release the sign-in's fraud signals to approved applications at consent, on the account page and on remembered reuse
- `1c37319869` FR-FRD-5, FR-FRD-6, FR-TOK-12, FR-CEN-13: tell the agency when a delegated token is issued, renewed or access is revoked
- `62ed7b7a4a` FR-FRD-6, FR-FRD-8: publish the delegated-access Attempts events in the API schema
- `990dbb3ab8` FR-FRD-6: fraud-signal delivery to agencies is on by default
- `279e58a2f2` FR-FRD-1, FR-FRD-8: the delegation buffer rides in the session's KMS-encrypted part
- `a9a88e262c` FR-FRD-5, FR-FRD-6: delegated events are written through the Attempts event catalog
- `1a9ad371ee` FR-FRD-5, FR-FRD-6, FR-TOK-12: the refresh grant and family revocation tell the agency

## How to review

Diff against `delegated-access-billing-reporting`. Check first: `Tracker#track_event` (return value and `should_track?` unchanged for the service provider's own event; no `AgencyIdentity` created for the buffer), the three release points and the once-only guards, that nothing names an unapproved application, the writer's two paths (what a server-side event omits), and `SENSITIVE_PATHS`. Run `make lint_tracker_events`. Specs: the four `attempts_api/*` specs, the events spec (an unlisted agency, a listed agency without a key, and the switch off each receive nothing), the tracker spec. Must not change for existing clients: existing event types and members are unchanged (FR-FRD-8); a service provider's direct Attempts delivery is byte for byte as before; an environment with no enrolled agency delivers nothing.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review, D74): default on, buffer via `SENSITIVE_PATHS` (no per-event KMS call), one event catalog, renewal and family end reported through `revoke_family!` (plan 5.7 items 12 to 15).
- Open for the privacy review (plan 5.7 item 11): the buffer carries the whole sign-in including failed-password events with the typed email; the hashed `unique_session_id` correlates service provider and agency events; a mid-session revocation ends tokens but not live fan-out; the `idv-*` history is released whether or not the request was an identity-verification request (ATT-15).
- Held until the harness run (plan 6.1): `AttemptsApi::HistoricalRelease` and `EventDelivery` extracted from `DelegatedRelease`.

## Depends on / depended on by

Depends on `delegated-access-consent` (the release point), the account page (approvals controller), the exchange and lifecycle branches (token events, `revoke_family!`), and the registry (`attempts_recipient`); placed after billing by D64. Depended on by `delegated-access-config-content` by position only.
