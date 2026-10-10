# delegated-access-saml-assertions

## Purpose

Plan 5.9, SAML assertions as an issued token type. For a resource server registered `token_format: saml2` the exchange and refresh mint a signed SAML assertion (encrypted to the agency's certificate when one is registered) instead of an opaque token, through an adapter over the IdP's own `SamlIdp::AssertionBuilder`; introspection and revocation accept the assertion ID or the encoded assertion. The foundation had nothing here.

## Requirements it satisfies

FR-TOK-9, FR-VER-9. Companion §15 (SAML-1..15 as amended in §15.8).

## What it adds / removes and why

Adds:
- `lib/saml_idp_extensions/assertion_builder.rb`, prepended from `config/initializers/saml_idp.rb`: `InResponseTo` only when there is a request id, `subject_confirmation_expiry:`, `issue_instant:`; each a no-op for the browser flow, pinned byte for byte by `spec/lib/saml_idp_extensions/assertion_builder_spec.rb` (SAML-15).
- `DelegatedSamlAssertion`: `Issuer` the metadata entityID; persistent `NameID` the agency-level identifier (`DelegatedTokenClaims#agency_sub`); bearer `SubjectConfirmation` with `Recipient` and `Audience` the resource server identifier; both `NotOnOrAfter` values the issuance record's lifetime (`token_exchange_saml_assertion_ttl_seconds`, 300, capped by `max_access_token_seconds` and the family end); `AuthnInstant` the sign-in's `last_authenticated_at`; the attribute statement from `AttributeAsserter` (now accepting `authn_request: nil`) for the agency's bundle with `uuid` re-pointed at the agency identifier and `email` at the shared address, plus `delegation_scopes`, `delegation_id`, `actor` and `dpop_jkt` for a bound family (E30). Identifiers only once the sign-in ended (`#identifiers_only?`). Signed with the `SamlEndpoint` key; encrypted to `resource_server.ssl_certs.first` when present (D45).
- Issuance in `OpenidConnectTokenExchangeForm#issue!` when `resource_server.saml?` (D70): record `token_format: saml2`, `token_type: N_A`; the assertion built inside the transaction; the live entry keyed by the SHA-256 of the assertion `ID`; the XML never stored. Response `access_token` is the base64url assertion, `issued_token_type` the saml2 URN, `session_live: false` present only when false (D73).
- Refresh re-issues what the exchange issued (`TokenExchangeRefreshToken#saml?` reads the issuance record) with a new `ID` and windows (SAML-9).
- `DelegatedSamlAssertion.reference_for(token)` lets `OpenidConnectIntrospectForm` and `OpenidConnectRevokeForm` accept an ID or an encoded plaintext assertion (at most 64 KB, parsed strictly without network access); an encrypted assertion hides its ID and is not active or not acted on. Revoke by ID ends that assertion only (D69).
- Fixture: the SAML API (`https://benefits-api.agency.localdev`) keeps its encryption certificate; the assertion is encrypted when the certificate file is present locally.

Removes: the `saml_not_available` refusal of the exchange branch; `REQUESTED_FORMAT_MUST_MATCH_RESOURCE`, its `requested_token_type_mismatch` strings and the `attributes: "identifiers_only"` member, all built under D44 and withdrawn by D70 and D73.

## Key decisions

- D44 as first built (service provider chooses the format; `requested_token_type` required), replaced by D70 (the registered `token_format` decides; the parameter optional; a mismatch is logged, not refused; rejected: `invalid_target` on mismatch, or keeping the parameter required).
- D45 five-minute windows, always signed, encrypted to the registered certificate when one exists.
- D69 revoke-by-ID ends the assertion only (rejected: ending the family, which would make the two formats differ at one endpoint); D73 `session_live: false` on the token response (rejected: the ported string; dropping the member).

## Key files

Models: `app/models/token_exchange_token.rb` (`lifetime_seconds_for(token_format:)`), `app/models/token_exchange_refresh_token.rb` (`#token_format`, `#saml?`).
Forms: `app/forms/openid_connect_token_exchange_form.rb`, `app/forms/openid_connect_refresh_token_form.rb`, `app/forms/openid_connect_introspect_form.rb`, `app/forms/openid_connect_revoke_form.rb`.
Services: `app/services/delegated_saml_assertion.rb`, `app/services/attribute_asserter.rb`.
Lib/config: `lib/saml_idp_extensions/assertion_builder.rb`, `config/initializers/saml_idp.rb`.
Migrations: none.
Specs: `spec/requests/openid_connect/saml_assertion_exchange_spec.rb` (both client types end to end: encrypted and signed assertion checked as a relying party checks it, refresh after the sign-in ends, introspection and revocation by ID and by encoded assertion), `spec/services/delegated_saml_assertion_spec.rb`, `spec/lib/saml_idp_extensions/assertion_builder_spec.rb`, `spec/services/attribute_asserter_spec.rb`, `spec/models/token_exchange_token_spec.rb`, `spec/requests/openid_connect/token_exchange_spec.rb`.
Config/locales: `lib/identity_config.rb` and `config/application.yml.default` (`token_exchange_saml_assertion_ttl_seconds`), `config/delegated_access.localdev.yml`, `config/locales/{en,es,fr,zh}.yml` (strings removed).

## Commits

- `e504a67029` FR-TOK-9: SAML assertion adapter on the IdP's assertion builder
- `58aa12d8ab` FR-TOK-9: issue and refresh SAML assertions at the token endpoint
- `79d1fc5de3` FR-TOK-9, FR-VER-9: introspection and revocation by assertion ID
- `80aacf18b2` FR-TOK-9, FR-VER-9: session_live in the SAML token response; registered format decides

## How to review

Diff against `delegated-access-introspection`. Check first: the builder extension is a no-op for the browser flow (the byte-for-byte spec), the assertion's `Audience`, `Recipient` and both `NotOnOrAfter` values, which attributes appear once the sign-in has ended, and `reference_for` input limits. Specs: `saml_assertion_exchange_spec.rb`, the assertion service spec, the builder extension spec. Must not change for existing clients: the SAML browser flow's assertions are byte-identical to the gem's own output; `AttributeAsserter` with an AuthnRequest behaves as before.

## Known open items and later amendments

- Amended 2026-10-11 (D70, D73): registered format decides, mismatch predicate and strings removed, `session_live: false` replaces `attributes: "identifiers_only"` (plan 5.9 item 9).
- Revocation of an issued assertion is observed by the agency only at expiry, which the five-minute window bounds (D45); revoke-by-ID narrowing of SAML-12 is recorded for review (D69).
- Held until the harness run (plan 6.1): `DelegatedTokenClaims` exposing identity, email and PII to the builder.

## Depends on / depended on by

Depends on `delegated-access-introspection` (`agency_sub`, `session_live?`, the bundle bounding, the introspect form), the lifecycle branch (refresh, revoke form) and the exchange branch (`#issue!`). Depended on by `delegated-access-operations` (the threat sweep and fixture contract name the saml2 API) and by position by billing, fraud signals and config-content.
