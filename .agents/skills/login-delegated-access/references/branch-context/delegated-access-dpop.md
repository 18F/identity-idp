# delegated-access-dpop

## Purpose

Section 5, client key binding (RFC 9449 DPoP) for the public-client service provider. The branch is the whole proof-of-possession layer in one reviewable unit (D64): the proof verifier, the `dpop_jkt` binding of the authorization request and code, the DPoP-bound code exchange, the `DPoP` scheme at userinfo and the document images endpoint, and the removal of the per-API `dpop_required` flag. It was assembled from commits first built with 5.4, 5.6 and 5.11 and relocated by rebase, so the exchange, lifecycle and introspection branches above it only call the verifier and compare thumbprints.

Amended 2026-10-13 (D82): key binding is a per-client setting, `service_providers.dpop_required` (default false, public clients only), independent of delegation approval. `ServiceProvider#dpop_bound?` (`pkce` and `dpop_required`) decides alone where the forms and the call sites asked `delegation_service_provider?` before. A flagged client is bound strictly; an unflagged public client approved for delegation is a bearer client end to end, at the token exchange included. As built, 2026-10-13: pending.

## Requirements it satisfies

FR-TOK-19, FR-TOK-22, FR-TOK-23 (the parts built here), FR-TOK-24, FR-TOK-25 (each as amended 2026-10-13, D82). Protocol rows EXC-17 to EXC-19 and EXC-19a (section 5); decisions D19 to D22, D46, D47, D64 and D82 (section 16).

## What it adds / removes and why

Adds:
- `DpopProofVerifier`: the RFC 9449 §4.3 checks in order (`typ` `dpop+jwt`, `alg` in `ALLOWED_ALGORITHMS` ES256/RS256, public-only `jwk`, signature, `htm`, normalized `htu`, `iat` within `dpop_proof_max_age_seconds` (300) either side of now, `ath` when a token accompanies the proof, expected thumbprint when the token is bound, single-use `jti` last so a rejected proof never consumes one). Missing proof, key mismatch and replay get their own description; every other failure shares one, so the response does not help tune a forged proof. No server nonce (D22).
- `ReplayGuard.first_use?(namespace:, scope:, value:, ttl:)`: the one Redis `SET NX` for single-use values, keyed by namespace and a SHA-256 of presenter and value; the proof `jti` is recorded under the key thumbprint for twice the window. The token-exchange branch reuses it for client-assertion `jti`.
- `OpenidConnectAuthorizeForm#dpop_jkt`: required for a `pkce` client approved for delegation (`dpop_binding_required?`, `dpop_jkt_required`; amended 2026-10-13, D82: required when the record sets `dpop_required`, through `ServiceProvider#dpop_bound?`), accepted well-formed from any client (`BASE64URL_SHA256_FORMAT`, shared with the S256 `code_challenge` check); stored through `IdentityLinker#link_identity(dpop_jkt:)` on `identities.dpop_jkt` only when binding applies (D21).
- `OpenidConnectTokenForm#validate_dpop_proof`: after every other check for such a client; a code whose identity has no thumbprint is refused (`dpop_code_unbound`); the proof is verified once per form against `identities.dpop_jkt`; the response reports `token_type: DPoP`. `OpenidConnect::TokenController#form_params` reads the proof from the `DPoP` header only.
- `AccessTokenVerifier#verify_key_binding`: a bound token under `Bearer` refused (`bound_token_requires_dpop`), an unbound token under `DPoP` refused (`token_not_bound`), `WWW-Authenticate: DPoP algs="ES256 RS256"` on the 401; `OpenidConnect::UserInfoController` and `OpenidConnect::DocumentImagesController` pass header, method and URL. `#load_identity` still reads `identities` only, so delegated tokens stay refused with or without a proof.
- `spec/support/delegated_access_helper.rb` (`DelegatedAccessHelper` for client assertions, `DpopHelper` with one P-256 key per example), included from `spec/rails_helper.rb`; the consent feature spec sends `dpop_jkt` as the browser client does (D57).

Removes:
- `token_exchange_resource_servers.dpop_required` (migration `20261009120000`, `safety_assured`), its factory trait, seeder and updater expectations and the two localdev fixture keys: binding follows the client type, never the API (D47).

Adds (amended 2026-10-13, D82; as built pending):
- `service_providers.dpop_required` (boolean, default false), seeded from `service_providers.yml` in identity-idp-config and written by `ServiceProviderUpdater` once the Dashboard has the field, like the other partner settings (D7). `ServiceProvider#dpop_bound?` is `pkce` and `dpop_required`; every place that decided binding by `pkce` plus delegation approval reads it instead.
- Strict when set: a flagged client's authorize request without `dpop_jkt` is refused (`dpop_jkt_required`); its code exchange, token exchange, refresh, userinfo and own introspection require proofs as before.
- Bearer when unset: an unflagged public client approved for delegation gets a bearer access token at the code exchange, exchanges it with `client_id` alone and no proof, receives bearer delegated tokens (no `cnf` on introspection, no `dpop_jkt` SAML attribute) and refreshes without a proof. The exchange, lifecycle, introspection and SAML branches gate their verifier calls and thumbprint comparisons on the predicate.
- The flag is ignored on a confidential client, with a warning. `ServiceProviderSeeder` and `ServiceProviderUpdater` warn when a delegation-approved public client lacks the flag ("its delegated tokens will be bearer tokens") and when a confidential client has it.
- `config/delegated_access.localdev.yml` (and the configuration repository's file) set `dpop_required: true` on the reference browser client (MyBenefits Assistant), so the harness keeps exercising DPoP.

Stays elsewhere: `ResourceServerAuthenticator` and `DelegatedAccessClientHandling` (5.4, 5.5), the CORS rules for revoke and introspect (5.5, 5.6), the discovery members (5.11).

## Key decisions

- D19 public client with DPoP (baseline change of 2026-10-09; the confidential-client wording withdrawn); D20 mandatory for every public client approved for delegation; D21 the code bound through `dpop_jkt`; D22 server nonces deferred (rejected: `DPoP-Nonce` round trip, nonce state at Login.gov and every agency).
- D46 ES256 and RS256; D47 no `dpop_required` flag; D64 one branch for the layer (rejected: leaving each piece where it was first needed).
- Proof window ±300 s, `jti` kept two windows (section 5, As built); the earlier 60 s back / 10 s forward window is superseded.
- D82 (2026-10-13): key binding is a per-client setting, `service_providers.dpop_required`, independent of delegation approval; public clients only; strict when set; an unflagged delegation client is a bearer client end to end. Rationale: onboarding flexibility for public clients that cannot implement DPoP yet, tightened later by setting the flag. Rejected: mandatory for delegation-approved public clients with the flag only widening the set (the recommendation); the flag on confidential clients; a soft mode that falls back to bearer when no thumbprint is sent. Security consequence: for an unflagged client the exposure D19 to D22 closed is accepted as an onboarding trade-off, mitigated by 15-minute lifetimes, rotation with reuse detection, revocation cascades and the seeder warning; every delegation-approved public client should set the flag before production (plan 6 item 19). D20 and D47 narrowed, not withdrawn: binding is still never per API.

## Key files

Forms: `app/forms/openid_connect_authorize_form.rb`, `app/forms/openid_connect_token_form.rb`.
Services: `app/services/dpop_proof_verifier.rb`, `app/services/replay_guard.rb`, `app/services/access_token_verifier.rb`, `app/services/identity_linker.rb`.
Controllers: `app/controllers/openid_connect/token_controller.rb`, `app/controllers/openid_connect/user_info_controller.rb`, `app/controllers/openid_connect/document_images_controller.rb`.
Migrations: `20261009100500_add_dpop_jkt_to_identities`, `20261009120000_remove_dpop_required_from_token_exchange_resource_servers`.
Specs: `spec/services/dpop_proof_verifier_spec.rb`, `spec/services/replay_guard_spec.rb`, `spec/services/access_token_verifier_spec.rb`, `spec/services/identity_linker_spec.rb`, `spec/forms/openid_connect_{authorize,token}_form_spec.rb`, `spec/requests/openid_connect/token_spec.rb`, `spec/requests/openid_connect_userinfo_spec.rb`, `spec/features/openid_connect/delegated_access_consent_spec.rb`, `spec/support/delegated_access_helper.rb`, `spec/factories/token_exchange_resource_servers.rb`.
Config/locales: `lib/identity_config.rb` and `config/application.yml.default` (`dpop_proof_max_age_seconds`), `config/delegated_access.localdev.yml`, `config/locales/{en,es,fr,zh}.yml` (`invalid_dpop_proof`, `dpop_jkt_required`, `dpop_jkt_invalid`, `bound_token_requires_dpop`, `token_not_bound`).

## Commits

- `efb6c1fe48` FR-TOK-22, FR-TOK-24, FR-TOK-25: DPoP proof verification and bound authorization codes
- `22bd136cac` FR-TOK-6, FR-TOK-24: userinfo requires the DPoP proof for a key-bound access token
- `2f31c731e8` FR-TOK-25: the consent screen's end-to-end spec signs in as a key-bound public client
- `716a87cff6` FR-TOK-22, FR-TOK-24: key binding follows the client type; the per-API dpop_required flag is dropped
- `2bb8394a01` FR-TOK-22: ReplayGuard records single-use values; the proof verifier reads its jti check from it
- `22416c0d05` FR-TOK-25: one format constant for a base64url SHA-256 on the authorize form

## How to review

Diff against `delegated-access-site-keys`. Read `DpopProofVerifier` once against RFC 9449 §4.3 and check the order of checks (the `jti` last). Then `dpop_binding_required?` on both forms (only `pkce` and `delegation_service_provider?`), the `identities.dpop_jkt` write, and `verify_key_binding`. Specs: the verifier spec, the token request spec, the userinfo request spec (a confidential client's bearer request is compared byte for byte with and without a stray `DPoP` header). Must not change for existing clients: confidential clients and public clients not approved for delegation keep bearer tokens and never see a challenge; `dpop_jkt` is optional for them. After D82, check `ServiceProvider#dpop_bound?` is the only predicate (never `pkce` plus delegation approval), that a flagged client is refused without `dpop_jkt` at authorize, that an unflagged public client approved for delegation is a bearer client end to end (code exchange, exchange with `client_id` alone, refresh, introspection without `cnf`, SAML without the thumbprint attribute), that the flag has no effect on a confidential client beyond the warning, and that both seeder warnings fire.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): `ReplayGuard` and `BASE64URL_SHA256_FORMAT` (section 5, As built); `ath` via `Digest::SHA256.urlsafe_base64digest`.
- D22 revisit triggers: partner clock skew, pre-computed proofs observed, or an agency asking for nonces.
- Held until the harness run (Appendix D.3): `Addressable` for `htu` normalization.
- Amended 2026-10-13 (D82): `service_providers.dpop_required`, `ServiceProvider#dpop_bound?`, the bearer path for an unflagged public client, the two seeder and updater warnings, the fixture flag on the reference browser client (section 5 As built; EXC-19a; section 16, D82). As built, 2026-10-13: pending.
- Review item (D82): every delegation-approved public client sets `dpop_required` before production; the Dashboard needs the field before partners can set it there.

## Depends on / depended on by

Depends on `delegated-access-site-keys` by position and on the registry (`pkce` plus `delegation_service_provider?` records; after D82 the `dpop_required` column and `ServiceProvider#dpop_bound?`) and consent (the feature spec). Depended on by `delegated-access-token-exchange` (proof at the exchange with `ath`, `identities.dpop_jkt` as the expected thumbprint), `delegated-access-token-lifecycle` (proof at refresh and revoke), `delegated-access-introspection` (the service provider's own introspection and the `DPoP` scheme at userinfo) and the operations branch (`ALLOWED_ALGORITHMS` in discovery).
