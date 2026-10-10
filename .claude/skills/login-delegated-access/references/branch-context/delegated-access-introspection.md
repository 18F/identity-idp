# delegated-access-introspection

## Purpose

Plan 5.6, agency verification. `POST /api/openid_connect/introspect` (RFC 7662): the resource server named in `aud` authenticates with `private_key_jwt` and receives the full active response with the agency-level `sub`, `act`, `delegation_id` and the identity attributes its registered bundle allows while the sign-in is live; the public-client service provider may introspect its own token with a DPoP proof and receives a limited response; everyone else gets `{"active": false}`. The foundation's agency would have called userinfo with a token the service provider also held.

## Requirements it satisfies

FR-VER-1 to FR-VER-8, FR-TOK-5, FR-TOK-6. Companion §6 (INT-1..11 as amended in §6.4, INT-13 to INT-16), NIST IR 8587 §5.2.1.1 element list.

## What it adds / removes and why

Adds (nothing of the foundation remains here after the exchange branch):
- `OpenidConnect::IntrospectController` (reads `OpenidConnect::DelegatedEndpointConcern`: 404 while `token_exchange_enabled` is off, no session or CSRF, `options`, proof from the `DPoP` header only) and `OpenidConnectIntrospectForm` (includes `DelegatedAccessClientHandling` with `client_key_source` `:resource_server`). A client assertion means a resource server (`ResourceServerAuthenticator`, `aud` the introspect URL; failure 401 `invalid_client`). A bare `client_id` naming a `pkce` record approved for delegation means the service provider, whose proof with `ath` over `token` is required; a proof failing on its own terms is 401 `invalid_dpop_proof` with `WWW-Authenticate: DPoP algs="ES256 RS256"`. No credential, an unknown or confidential `client_id`, or a proof signed by a key other than the token's is 200 `{"active": false}` (D62).
- Validity: `DelegatedTokenStore.read`, `expires_at` in the future, user present and not suspended, grant `valid_now?`, resource server `usable?`, the token's service provider still `delegation_service_provider?`; entitlement is the caller being the entry's resource server or the bound service provider. The issuance record is not consulted (INT-15).
- Full response: `active`, `iss`, `aud`, `scope`, `client_id`, `delegation_id`, `token_type`, `iat`, `exp`, `cnf: {jkt}` when bound, `sub` (`DelegatedTokenClaims#agency_sub`, the `AgencyIdentity` uuid created if missing, never an `identities` row, D35), `act: {sub: <issuer>}`, `jti` (the hex digest, D63), `acr`, `aal`, `auth_time`, `session_live`, then the claims.
- `DelegatedTokenClaims`: maps the application's `attribute_bundle` to the scopes that release the same claims (`BUNDLE_SCOPES`), builds every claim userinfo could produce and filters through `OpenidConnectAttributeScoper`; while the sign-in is live (`OutOfBandSessionAccessor` TTL on `sp_rails_session_id`) the bundle from the decrypted profile; afterwards `sub`, `delegation_id`, `email` (with `email_verified`, `all_emails` when bundled) and `session_live: false` (D34).
- Limited response to the service provider: the common members plus its own pairwise `sub` and the claims in `service_providers.delegation_sp_shareable_attributes` (migration `20261009110000`, empty by default) intersected with the bundle (D36).
- `OpenidConnectClaimsFormatter#identity_proofing_claims`/`#x509_claims`, lifted from `OpenidConnectUserInfoPresenter`, so userinfo and introspection produce one claim shape.
- `Rack::Cors` treatment for the path (D59); `openid_connect_introspect` analytics; no cache guidance and no rate limit (D37).

## Key decisions

- D26 one Redis read by digest; D29 opaque references (rejected: JWTs, visible to the carrier and still needing introspection for revocation).
- D34 attributes by session state; D35 agency-level `sub` without an `identities` row; D36 who may introspect, read through D62 (wrong key is `active: false`, not 401).
- D37 agencies introspect on every call, so revocation is seen immediately; D59 CORS; D63 `jti` is the digest (amends INT-4's "never the digest itself").

## Key files

Forms: `app/forms/openid_connect_introspect_form.rb`, `app/forms/concerns/delegated_access_client_handling.rb` (resource-server parameterization).
Services: `app/services/delegated_token_claims.rb`, `app/services/openid_connect_claims_formatter.rb`, `app/services/analytics_events.rb`.
Controllers/views: `app/controllers/openid_connect/introspect_controller.rb`, `app/presenters/openid_connect_user_info_presenter.rb` (calls the formatter).
Migrations: `20261009110000_add_delegation_sp_shareable_attributes_to_service_providers`.
Specs: `spec/requests/openid_connect/introspect_spec.rb`, `spec/forms/openid_connect_introspect_form_spec.rb`, `spec/services/delegated_token_claims_spec.rb`, `spec/requests/openid_connect_cors_spec.rb`, `spec/services/delegated_access_seeder_spec.rb`, `spec/services/service_provider_seeder_spec.rb`.
Config/locales: `config/application.rb` (CORS for `/api/openid_connect/introspect`), `config/routes.rb`, `config/delegated_access.localdev.yml` (`delegation_sp_shareable_attributes`).

## Commits

- `115beb8d31` FR-VER-1, FR-VER-2, FR-VER-3, FR-VER-4, FR-VER-5, FR-VER-6, FR-VER-8, FR-TOK-5: token introspection for agency APIs and the service provider
- `2098895cad` FR-VER-1, FR-VER-2: introspection reads the shared client handling and endpoint plumbing

## How to review

Diff against `delegated-access-token-lifecycle`. Check first: the caller rules (which outcomes are 401 and which are `active: false`), the validity list and the entitlement comparison in the form, `DelegatedTokenClaims` filtering (one claim at a time for names, composite `address`, nothing released empty), and the limited response's member set (no `act`, `jti`, `acr`, `aal`, `auth_time`, `session_live`). Specs: `introspect_spec.rb` (50 examples), the claims spec, the formatter and userinfo specs. Must not change for existing clients: userinfo's response shape is unchanged after the formatter extraction (the presenter spec and userinfo request spec pin it); the endpoint is 404 with the switch off.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): the form on `DelegatedAccessClientHandling`, the controller on `DelegatedEndpointConcern` (plan 5.6 item 11).
- The released `email` is the one shared with the service provider (INT-13) until decided otherwise.
- Held until the harness run (plan 6.1): `DelegatedTokenClaims` exposing identity, email and PII to the SAML builder so `DelegatedSamlAssertion` stops reading them itself.
- The SAML branch extends the form to accept an assertion ID or an encoded assertion as `token`.

## Depends on / depended on by

Depends on `delegated-access-token-lifecycle` (revoked state, the two shared concerns), the exchange branch (live entry), the DPoP branch (proof and the `DPoP` scheme) and the registry (resource server certificates). Depended on by `delegated-access-saml-assertions` (`agency_sub`, `session_live?`, attribute bounding; introspection by assertion ID) and the operations branch (discovery names the route; the threat sweep calls the endpoint).
