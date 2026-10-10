# delegated-access-token-lifecycle

## Purpose

Plan 5.5, token lifecycle: refresh, revocation, suspension and deletion. Every exchange opens a refresh family (rotating, digest-only rows, 12-hour absolute end, never past the approval's `remember_until`); the `refresh_token` grant at the token endpoint mints the next token with reuse detection; `POST /api/openid_connect/revoke` (RFC 7009) ends a family or one token; grant revocation, account suspension and account deletion cascade to every live token. The foundation had nothing here: its token died with the browser session.

## Requirements it satisfies

FR-TOK-10, 11, 12, 13, 14, 15, 16, 18, 20 (refresh half); FR-CEN-13, FR-CEN-15 (suspension and deletion). Companion §7 (REF-1..9 as amended in §5.5 and §7.6), §11.

## What it adds / removes and why

Adds (nothing of the foundation remains here after the exchange branch):
- `TokenExchangeRefreshToken` (`token_exchange_refresh_tokens`, migration `20261009100800`): `token_digest` unique, `family_id`, `grant_id`, `token_exchange_token_id`, scope and `dpop_jkt` copied from the family, `expires_at` (the family's end, same on every row), `used_at`, `rotated_at`, revocation fields; `.lookup` refuses null bytes. `family_end` is the lowest of `token_exchange_refresh_token_ttl_seconds` (43200), `max_family_seconds` (migration `20261009100900`) and `delegation_max_family_seconds` (migration `20261009101000`), counted from the exchange that opens the family (D32, D61); `TokenExchangeToken.lifetime_seconds_for` caps every access token by the seconds left in its family.
- `DelegatedAccessClientHandling` (`app/forms/concerns/`): `validate_client` lifted out of the exchange form and shared by the exchange, refresh and revoke forms, with `fail_with`, `error_response`, `url_options`, `validate_code_verifier_absent`, `integration_errors`; `OpenidConnect::DelegatedEndpointConcern` for what the revoke and introspect controllers share (switch check, no session or CSRF, `options`, `DPoP` header merged into params).
- `OpenidConnectRefreshTokenForm`: checks in order (`code_verifier` absent, client, no `resource` (`resource_not_allowed_on_refresh`), token present, the public client's proof before the token is looked up, token this client's, thumbprint equal to the family's, `scope` exactly the family's); `#rotate_and_mint!` re-reads under `SELECT … FOR UPDATE`, refuses a revoked or ended row, revokes the family with `approval_lapsed` when `approval_stands?` is false, refuses without revoking when the API or application is switched off, else `#mint!` writes the next record and refresh row and the live entry. A spent row presented again revokes the family (`refresh_token_reuse`), answers `invalid_grant` (`refresh_token_reused`) and logs `delegation_refresh_token_reuse` (D33).
- `OpenidConnect::RevokeController` and `OpenidConnectRevokeForm`: `token_type_hint` orders two lookups; a refresh token ends its family (`client_revoked`), a live access token is removed alone (`DelegatedTokenStore.revoke_token`); unknown, foreign or already revoked tokens are not acted on; every authenticated outcome is 200 `{}`. The path gets the token endpoint's `Rack::Cors` treatment (D59).
- Cascades: `TokenExchangeToken.revoke_rows!` marks a relation of issuance records or refresh rows; `TokenExchangeGrant#revoke!` uses it for both; `TokenExchangeRefreshToken.revoke_family!` deletes the family's live entries, marks its rows and reports to the Attempts seam. `TokenExchangeGrant.revoke_all_for_user!` is called by `User#suspend!` (`account_suspended`) and by `Users::DeleteController` and `AccountReset::DeleteAccount` (`account_deleted`) inside their transactions. Sign-out calls nothing.
- Exchange response gains `refresh_token` and `refresh_token_expires_in`; `#issue!` writes the family's first refresh row.

## Key decisions

- D26 refresh rows and issuance records in Postgres, live entries in Redis; D27 `max_access_token_seconds` applied at every refresh.
- D32 twelve hours from the first exchange, never past `remember_until` (rejected: ending with the Login.gov session for non-remembered approvals; a 4-hour default); D61 the clock starts per family (rejected: one clock per approval).
- D33 reuse revokes the family and reports `refresh_token_reuse`; D37 no ceiling; D59 CORS on the revocation endpoint.

## Key files

Models: `app/models/token_exchange_refresh_token.rb`, `app/models/token_exchange_token.rb` (`lifetime_seconds_for`, `revoke_rows!`), `app/models/token_exchange_grant.rb` (`revoke_all_for_user!`), `app/models/user.rb` (`suspend!`).
Forms: `app/forms/openid_connect_refresh_token_form.rb`, `app/forms/openid_connect_revoke_form.rb`, `app/forms/concerns/delegated_access_client_handling.rb`, `app/forms/openid_connect_token_exchange_form.rb` (uses the concern, writes the first refresh row).
Services: `app/services/delegated_token_store.rb` (`revoke_family`, `revoke_token`), `app/services/account_reset/delete_account.rb`, `app/services/analytics_events.rb` (`openid_connect_token_refresh`, `openid_connect_revoke`, `delegation_refresh_token_reuse`).
Controllers: `app/controllers/openid_connect/revoke_controller.rb`, `app/controllers/concerns/openid_connect/delegated_endpoint_concern.rb`, `app/controllers/openid_connect/token_controller.rb` (refresh dispatch), `app/controllers/users/delete_controller.rb`.
Migrations: `20261009100800_create_token_exchange_refresh_tokens`, `20261009100900_add_max_family_seconds_to_token_exchange_resource_servers`, `20261009101000_add_delegation_max_family_seconds_to_service_providers`.
Specs: `spec/requests/openid_connect/token_refresh_spec.rb`, `spec/requests/openid_connect/revoke_spec.rb`, `spec/requests/openid_connect/token_exchange_spec.rb`, `spec/requests/openid_connect_cors_spec.rb`, `spec/models/token_exchange_refresh_token_spec.rb`, `spec/models/token_exchange_grant_spec.rb`, `spec/models/user_spec.rb`, `spec/controllers/users/delete_controller_spec.rb`, `spec/services/account_reset/delete_account_spec.rb`, `spec/services/delegated_token_store_spec.rb`, `spec/factories/token_exchange_refresh_tokens.rb`.
Config/locales: `config/application.rb` (CORS for `/api/openid_connect/revoke`), `config/routes.rb`, `lib/identity_config.rb` and `config/application.yml.default` (`token_exchange_refresh_token_ttl_seconds`), `config/delegated_access.localdev.yml` (`max_family_seconds: 14400` on the records API), `config/locales/{en,es,fr,zh}.yml` (`invalid_refresh_token`, `refresh_scope_mismatch`, `refresh_token_missing`, `refresh_token_reused`, `resource_not_allowed_on_refresh`, `openid_connect.revoke.errors.token_missing`).

## Commits

- `4ea723cd45` FR-TOK-10, FR-TOK-11, FR-TOK-13, FR-TOK-16, FR-TOK-18, FR-CEN-13: refresh token families issued at exchange
- `f81049ea81` FR-TOK-10, FR-TOK-12, FR-TOK-13, FR-TOK-15, FR-TOK-20: refresh grant with rotation and reuse detection
- `a6f6553be9` FR-TOK-14: RFC 7009 revocation endpoint for delegated access
- `879f97d848` FR-CEN-15: account suspension and deletion revoke every approval
- `5389302b52` FR-TOK-10, FR-TOK-13: the refresh grant writes the record's live entry and reads OpaqueToken
- `f57f62d7bc` FR-TOK-12, FR-CEN-13: one cascade marks the rows an approval or a family revokes
- `2c8d996227` FR-TOK-14, FR-TOK-10: the delegated-access forms and endpoints share their plumbing
- `9d132cd53b` FR-TOK-9, FR-TOK-10: a refresh keeps the family's registered format

## How to review

Diff against `delegated-access-token-exchange`. Check first: `family_end` and `lifetime_seconds_for` (no access token outlives its family), `rotate_and_mint!` under the row lock and the three refusal paths (revoked/ended, approval lapsed, API switched off), the reuse path, `OpenidConnectRevokeForm` outcomes (always 200 once authenticated), and the two deletion call sites plus `suspend!`. Specs: `token_refresh_spec.rb`, `revoke_spec.rb`, the refresh token model spec, the user and deletion specs, the CORS spec. Must not change for existing clients: `grant_type=refresh_token` is dispatched only while `token_exchange_enabled` is on (otherwise `unsupported_grant_type` as before); account deletion and suspension for a user with no grants behave as before.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review, D70): `revoke_rows!`/`revoke_family!` with the Attempts calls wired through them (the empty `report_family_revoked` seam is gone), `#mint!` on `live_attributes` and `OpaqueToken`, the registered format kept on refresh, the shared concerns (plan 5.5 items 13 to 16).
- Held until the harness run (plan 6.1): a `User` deletion callback for the grant cascade in place of the two call sites; `ServiceProviderIdentity#session_live?`.
- Revocation by SAML assertion ID arrives with the SAML branch.

## Depends on / depended on by

Depends on `delegated-access-token-exchange` (issuance record, `refresh_family_id`, the store) and `delegated-access-dpop` (proof at refresh and revoke). Depended on by introspection (revoked state; `DelegatedEndpointConcern` and the client-handling concern), SAML (refresh of assertions, revoke by ID), fraud signals (`token_refreshed`, `access_revoked` through `revoke_family!`) and billing (refreshes write no billing row).
