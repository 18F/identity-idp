# delegated-access-token-exchange

## Purpose

Plan 5.4, server-to-server token exchange. RFC 8693 exchange at the existing token endpoint, dispatched on `grant_type`, with client handling by client type (`private_key_jwt` for a confidential client, `client_id` plus a DPoP proof for the public client), exactly one `resource`, an opaque delegated token stored as a Redis entry by digest plus a secret-free Postgres issuance record, and no `id_token`. It removes the foundation's browser-callable `/exchange` endpoint and its minting of a real target identity.

## Requirements it satisfies

FR-TOK-1, 2, 3, 4, 5, 6, 7, 8, 17, 19, 20 (exchange half), 21, 26; FR-CEN-8, FR-CEN-10, FR-CEN-12, FR-CEN-16. Companion §5 (EXC-1..12 as amended in §5.5 and §5.6, EXC-21), §6.2.

## What it adds / removes and why

Adds:
- `OpenidConnect::TokenController#build_form` as a `case params[:grant_type]`: `authorization_code`, the exchange URN while `token_exchange_enabled` is on, else `OpenidConnectUnsupportedGrantForm` (`unsupported_grant_type`, D71). The exchange logs `openid_connect_token_exchange`.
- `ResourceServerAuthenticator` (RFC 7523): RS256 pinned, `iss` equal to `sub`, every certificate on the record tried, `aud` the endpoint, `exp` at most five minutes after `iat`, `jti` recorded through `ReplayGuard` after signature verification; `key_source: :service_provider` here, `:resource_server` for agencies later.
- `OpenidConnectTokenExchangeForm` (new body, same name): `validate_client` by client type (credentials not interchangeable, `client_type_mismatch`; `client_not_approved` first), then request shape, subject token (a `ServiceProviderIdentity.not_deleted` row for this client's issuer, bound for a public client), the proof with `ath`, sign-in live (`OutOfBandSessionAccessor` TTL, D28), identity verification (`User#identity_verified?` plus the sign-in's IAL), the resource (`TokenExchangeResourceServer#usable?` and `accepts_delegation_from?`, one wording for every failure, `invalid_target`), the approval (`TokenExchangeGrant.live_by_application`, `valid_now?`; `consent_required` naming the application's scope, D31). No `scope` parameter is read (D72); `requested_token_type` is optional and the registered `token_format` decides (D70).
- `TokenExchangeToken` (`token_exchange_tokens`, migration `20261009100700`): the issuance record; `#issue!` writes it and the grant's `first_exchanged_at` in one transaction, then `DelegatedTokenStore.write` puts the live entry (`#live_attributes`) at `delegated_token:<hex SHA-256>` with TTL the lifetime, indexed per grant and per refresh family (D26). Lifetime is the lower of `token_exchange_access_token_ttl_seconds` (900) and `max_access_token_seconds` (migration `20261009100600`) (D27).
- `DelegatedAccess::OpaqueToken.generate`/`.digest`: the one source for every opaque string Login.gov hands out and looks up.
- Re-approval and revocation: `TokenExchangeGrant.approve!` supersedes earlier live rows and `#transfer_live_tokens_to!` moves their live entries (`DelegatedTokenStore.move_grant`, E97); `#revoke!` deletes the entries (`revoke_grant`) and marks open issuance rows, so `user_revoked` and `sp_disconnected` end tokens at once (FR-CEN-13).
- `AccessTokenVerifier#load_identity` comment: delegated tokens live in `DelegatedTokenStore`, are never found in `identities`, and no second lookup path is to be added.
- Fixture: MyBenefits Assistant becomes a public client (`pkce: true`, no `certs`) (D57).

Removes:
- `OpenidConnect::ExchangeController`, the `/api/openid_connect/exchange` routes and its `Rack::Cors` resource: the token endpoint already carries the CORS rule a browser client needs (FR-TOK-1).
- Minting through `IdentityLinker` against the target and the `id_token` with `act`; `IdTokenBuilder` back to `main`'s shape: a delegated token must not be a sign-in credential, read attributes or create a connection (FR-TOK-6, FR-CEN-12).
- The `target_in_use` check (no target identity to hijack) and the claim-space narrowing (attributes reach only the agency, bounded by its `attribute_bundle` at introspection).
- The foundation `OpenidConnectTokenExchangeForm` spec and the exchange controller spec, replaced.

## Key decisions

- D26 hybrid storage (rejected: Postgres-only, Redis-only); D27 900 s default, shorter per API, never longer; D28 sign-in live for the first exchange; D29 opaque reference (rejected: signed JWT); D30 exactly one `resource`.
- D31 `consent_required` only after authentication for a registered resource, everything else `invalid_target`; D37 no per-caller ceiling.
- D47 binding follows the client type; D57 the fixture service provider is a public client; D70 registered format decides (replaces D44); D71 `unsupported_grant_type`; D72 no scope narrowing.

## Key files

Models: `app/models/token_exchange_token.rb`, `app/models/token_exchange_grant.rb` (`transfer_live_tokens_to!`, revocation cascade).
Forms: `app/forms/openid_connect_token_exchange_form.rb`, `app/forms/openid_connect_unsupported_grant_form.rb`.
Services: `app/services/delegated_token_store.rb`, `app/services/delegated_access/opaque_token.rb`, `app/services/resource_server_authenticator.rb`, `app/services/access_token_verifier.rb`, `app/services/id_token_builder.rb` (reverted), `app/services/analytics_events.rb`.
Controllers: `app/controllers/openid_connect/token_controller.rb`; `app/controllers/openid_connect/exchange_controller.rb` deleted.
Migrations: `20261009100600_add_max_access_token_seconds_to_token_exchange_resource_servers`, `20261009100700_create_token_exchange_tokens`.
Specs: `spec/requests/openid_connect/token_exchange_spec.rb` (both client types end to end), `spec/forms/openid_connect_token_exchange_form_spec.rb`, `spec/forms/openid_connect_unsupported_grant_form_spec.rb`, `spec/models/token_exchange_token_spec.rb`, `spec/services/delegated_token_store_spec.rb`, `spec/services/resource_server_authenticator_spec.rb`, `spec/services/delegated_access/opaque_token_spec.rb`, `spec/requests/openid_connect_userinfo_spec.rb` (a live delegated token gets 401), `spec/factories/token_exchange_tokens.rb`.
Config/locales: `config/application.rb` (CORS resource removed), `config/routes.rb`, `lib/identity_config.rb` and `config/application.yml.default` (`token_exchange_access_token_ttl_seconds`), `config/delegated_access.localdev.yml`, `config/locales/{en,es,fr,zh}.yml` (`openid_connect.token.errors.*`).

## Commits

- `ab67d04ea2` FR-TOK-4, FR-TOK-5, FR-TOK-21, FR-CEN-13: issuance record, Redis token store and lifetime configuration
- `8a007209b2` FR-TOK-2, FR-TOK-19: private_key_jwt authentication for delegated-access endpoints
- `b08b1401a2` FR-TOK-1, FR-TOK-3, FR-TOK-5, FR-TOK-6, FR-TOK-7, FR-TOK-8, FR-TOK-17, FR-TOK-26, FR-CEN-8, FR-CEN-10, FR-CEN-12, FR-CEN-16: token exchange at the token endpoint
- `3d613f6d9b` FR-CEN-8, FR-CEN-13: re-approval keeps delegated tokens; revocation ends them
- `76038b7d84` FR-ONB-9, FR-TOK-24: register the sample service provider as a public client
- `21fc8d50e2` FR-TOK-2: the client assertion jti check reads ReplayGuard
- `893483569d` FR-TOK-4: DelegatedAccess::OpaqueToken generates and digests the opaque strings
- `baa7bdac91` FR-TOK-4, FR-TOK-5: the issuance record builds its own live entry
- `6a87477121` FR-TOK-7: the exchange reads identity verification from the user
- `aae81e26ef` FR-TOK-9, FR-TOK-3: the agency's registered format decides the issued token type

## How to review

Diff against `delegated-access-dpop`. Check first: the validation order in `OpenidConnectTokenExchangeForm` (nothing about the registry or approvals before the client is authenticated), `#issue!` (record in the transaction, Redis write after commit), `DelegatedTokenStore` key and index-set shapes, and `ResourceServerAuthenticator` (signature before the replay cache). Specs: the exchange request spec (every error class in order, replay of an assertion and of a proof, header-only proof, flag off, other grant types), the store and token model specs, the userinfo refusal. Must not change for existing clients: the `authorization_code` grant's responses are byte for byte the same; only a malformed `grant_type` changes its error text (D71, an error path).

## Known open items and later amendments

- Amended 2026-10-11 (reuse review, D70): `OpaqueToken`, `#live_attributes`, `User#identity_verified?`, the shared replay guard, optional `requested_token_type` with `requested_token_type_mismatch` logged (plan 5.4 items 17 to 21).
- On this branch an API registered `saml2` is still refused as `invalid_target` until the SAML branch; `refresh_token` is absent from the response until the lifecycle branch (the family id is already recorded).
- Held until the harness run (plan 6.1): `OpenidConnectTokenForm` delegating to `ResourceServerAuthenticator`; `ServiceProviderIdentity#session_live?` as the one TTL test.
- The billing branch adds `Billing::DelegatedReturnRecorder` and the fraud-signals branch adds `DelegatedAccessEvents.token_issued` to `#issue!`.

## Depends on / depended on by

Depends on `delegated-access-dpop` (proof verification, `identities.dpop_jkt`, `ReplayGuard`), `delegated-access-consent` (grants, `rails_session_id`) and the registry (resource servers). Depended on by `delegated-access-token-lifecycle` (refresh families attach to `refresh_family_id`, client handling moves into a concern), introspection (reads the live entry), SAML (`#issue!` mints assertions), billing (writes at the end of `#issue!`) and fraud signals (`token_issued`).
