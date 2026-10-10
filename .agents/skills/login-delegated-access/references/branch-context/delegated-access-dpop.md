# delegated-access-dpop

## Purpose

Plan 5.10, client key binding (RFC 9449 DPoP) for the public-client service provider. The branch is the whole proof-of-possession layer in one reviewable unit (D64): the proof verifier, the `dpop_jkt` binding of the authorization request and code, the DPoP-bound code exchange, the `DPoP` scheme at userinfo and the document images endpoint, and the removal of the per-API `dpop_required` flag. It was assembled from commits first built with 5.4, 5.6 and 5.11 and relocated by rebase, so the exchange, lifecycle and introspection branches above it only call the verifier and compare thumbprints.

## Requirements it satisfies

FR-TOK-19, FR-TOK-22, FR-TOK-23 (the parts built here), FR-TOK-24, FR-TOK-25. Companion §5.5 (EXC-17 to EXC-19), Appendix C as amended, Appendix E rows E28–E32, E53–E57, E98, E102.

## What it adds / removes and why

Adds:
- `DpopProofVerifier`: the RFC 9449 §4.3 checks in order (`typ` `dpop+jwt`, `alg` in `ALLOWED_ALGORITHMS` ES256/RS256, public-only `jwk`, signature, `htm`, normalized `htu`, `iat` within `dpop_proof_max_age_seconds` (300) either side of now, `ath` when a token accompanies the proof, expected thumbprint when the token is bound, single-use `jti` last so a rejected proof never consumes one). Missing proof, key mismatch and replay get their own description; every other failure shares one, so the response does not help tune a forged proof. No server nonce (D22).
- `ReplayGuard.first_use?(namespace:, scope:, value:, ttl:)`: the one Redis `SET NX` for single-use values, keyed by namespace and a SHA-256 of presenter and value; the proof `jti` is recorded under the key thumbprint for twice the window (E98). The token-exchange branch reuses it for client-assertion `jti`.
- `OpenidConnectAuthorizeForm#dpop_jkt`: required for a `pkce` client approved for delegation (`dpop_binding_required?`, `dpop_jkt_required`), accepted well-formed from any client (`BASE64URL_SHA256_FORMAT`, shared with the S256 `code_challenge` check); stored through `IdentityLinker#link_identity(dpop_jkt:)` on `identities.dpop_jkt` only when binding applies (D21).
- `OpenidConnectTokenForm#validate_dpop_proof`: after every other check for such a client; a code whose identity has no thumbprint is refused (`dpop_code_unbound`); the proof is verified once per form against `identities.dpop_jkt`; the response reports `token_type: DPoP`. `OpenidConnect::TokenController#form_params` reads the proof from the `DPoP` header only.
- `AccessTokenVerifier#verify_key_binding`: a bound token under `Bearer` refused (`bound_token_requires_dpop`), an unbound token under `DPoP` refused (`token_not_bound`), `WWW-Authenticate: DPoP algs="ES256 RS256"` on the 401; `OpenidConnect::UserInfoController` and `OpenidConnect::DocumentImagesController` pass header, method and URL. `#load_identity` still reads `identities` only, so delegated tokens stay refused with or without a proof.
- `spec/support/delegated_access_helper.rb` (`DelegatedAccessHelper` for client assertions, `DpopHelper` with one P-256 key per example), included from `spec/rails_helper.rb`; the consent feature spec sends `dpop_jkt` as the browser client does (D57).

Removes:
- `token_exchange_resource_servers.dpop_required` (migration `20261009120000`, `safety_assured`), its factory trait, seeder and updater expectations and the two localdev fixture keys: binding follows the client type, never the API (D47).

Stays elsewhere: `ResourceServerAuthenticator` and `DelegatedAccessClientHandling` (5.4, 5.5), the CORS rules for revoke and introspect (5.5, 5.6), the discovery members (5.11).

## Key decisions

- D19 public client with DPoP (baseline change of 2026-10-09; the confidential-client wording withdrawn); D20 mandatory for every public client approved for delegation; D21 the code bound through `dpop_jkt`; D22 server nonces deferred (rejected: `DPoP-Nonce` round trip, nonce state at Login.gov and every agency).
- D46 ES256 and RS256; D47 no `dpop_required` flag; D64 one branch for the layer (rejected: leaving each piece where it was first needed).
- E98: ±300 s window, `jti` kept two windows; amends the companion's "60 s back / 10 s forward".

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

Diff against `delegated-access-site-keys`. Read `DpopProofVerifier` once against RFC 9449 §4.3 and check the order of checks (the `jti` last). Then `dpop_binding_required?` on both forms (only `pkce` and `delegation_service_provider?`), the `identities.dpop_jkt` write, and `verify_key_binding`. Specs: the verifier spec, the token request spec, the userinfo request spec (a confidential client's bearer request is compared byte for byte with and without a stray `DPoP` header). Must not change for existing clients: confidential clients and public clients not approved for delegation keep bearer tokens and never see a challenge; `dpop_jkt` is optional for them.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): `ReplayGuard` and `BASE64URL_SHA256_FORMAT` (plan 5.10 items 7, 8); `ath` via `Digest::SHA256.urlsafe_base64digest`.
- D22 revisit triggers: partner clock skew, pre-computed proofs observed, or an agency asking for nonces.
- Held until the harness run (plan 6.1): `Addressable` for `htu` normalization.

## Depends on / depended on by

Depends on `delegated-access-site-keys` by position and on the registry (`pkce` plus `delegation_service_provider?` records) and consent (the feature spec). Depended on by `delegated-access-token-exchange` (proof at the exchange with `ath`, `identities.dpop_jkt` as the expected thumbprint), `delegated-access-token-lifecycle` (proof at refresh and revoke), `delegated-access-introspection` (the service provider's own introspection and the `DPoP` scheme at userinfo) and the operations branch (`ALLOWED_ALGORITHMS` in discovery).
