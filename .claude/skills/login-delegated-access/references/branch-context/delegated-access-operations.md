# delegated-access-operations

## Purpose

Plan 5.11, operations: discovery metadata advertised only while `token_exchange_enabled` is on, one caller property across every delegated-access analytics event, the fixture contract with the three reference applications stated in the fixture header and asserted by a spec, and a threat sweep that pins the cross-cutting refusals on the integrated endpoints. The foundation had the master switch (not advertised) and analytics events with properties that described a response that no longer exists.

## Requirements it satisfies

FR-OPS-1, FR-OPS-2, FR-OPS-4, FR-OPS-5 (IdP side). Companion §5.4 (DISC-1..5 as amended), §12, §13, §14.5 as amended.

## What it adds / removes and why

Adds:
- `OpenidConnectConfigurationPresenter`, only while the switch is on: `refresh_token` and `OpenidConnectTokenExchangeForm::GRANT_TYPE` in `grant_types_supported`; `none` beside `private_key_jwt` in `token_endpoint_auth_methods_supported`; `introspection_endpoint` and `revocation_endpoint` each with `*_auth_methods_supported` (`private_key_jwt`, `none`, E103) and `*_auth_signing_alg_values_supported` (`RS256`); `dpop_signing_alg_values_supported` from `DpopProofVerifier::ALLOWED_ALGORITHMS`. No `token_exchange_endpoint` (RFC 8693 defines none); `scopes_supported` stays static. The presenter spec holds the off-state document as a literal and asserts member and key-order equality (D48).
- One name for the caller: `delegation_consent_submitted`, `delegation_account_approved` and `delegation_account_revoked` log `service_provider_issuer` in place of `issuer`, as the token events do.
- Fixture contract (D51, D57): the header of `config/delegated_access.localdev.yml` names the three reference applications with their fictitious operators and relocation variables (`DELEGATION_SP_URL`, `DELEGATION_OIDC_AGENCY_URL`, `DELEGATION_SAML_AGENCY_URL`); `spec/services/delegated_access_seeder_spec.rb` asserts issuers, scope values, API identifiers (RFC 8707 resource indicators, unchanged by hostname), token formats, redirect URIs, `pkce` with no certificates, and no `dpop_required` key.
- `spec/requests/openid_connect/delegated_access_threats_spec.rb` (13 examples): foreign subject token in both directions, bound token as bearer at userinfo, delegated token at userinfo with and without a proof, replayed `jti` at the same and at another endpoint, proof for another URL, expired proof, refresh with another key, introspection by the wrong API, exchange after revocation, after the service provider lost approval, after the API or application was switched off; each refusal checked for its analytics event and error code.

Removes:
- The four `token_exchange_alert_*` configuration keys built first (error rate 5 percent, 1000 exchanges, 6000 introspections, 1000 refreshes per minute): nothing in the application read them; the values stand in plan 7.5 for the `identity-devops` alarms over the analytics stream (D37).
- The foundation's `openid_connect_token_exchange` properties (`broker_issuer`, `target_issuer`, `minted_ial`, `minted_scope`) are already gone with the exchange branch; `docs/token-exchange.md` with the registry branch.

Moved out by D64: the `dpop_required` removal, built here, now lives on `delegated-access-dpop`.

## Key decisions

- D37 thresholds, no ceiling; D46 ES256 and RS256; D48 discovery behind the switch (rejected: advertising endpoints that return 404 or `unsupported_grant_type`).
- D51 one fixture contract; D57 the service provider reference application is a browser public client (rejected: a confidential client; a server proxying proofs); D59 the sweep exercises the browser-callable endpoints.
- D64 the discovery members stay here because the presenter names routes that exist only from the lifecycle and introspection branches on.

## Key files

Controllers/presenters: `app/presenters/openid_connect_configuration_presenter.rb`, `app/controllers/sign_up/completions_controller.rb`, `app/controllers/accounts/delegated_access/approvals_controller.rb`, `app/controllers/accounts/delegated_access/revocations_controller.rb` (analytics property rename).
Services: `app/services/analytics_events.rb`.
Migrations: none.
Specs: `spec/presenters/openid_connect_configuration_presenter_spec.rb`, `spec/requests/openid_connect/delegated_access_threats_spec.rb`, `spec/services/delegated_access_seeder_spec.rb`, the three controller specs.
Config: `config/delegated_access.localdev.yml` (header and contract).

## Commits

- `dc35871814` FR-OPS-1: discovery advertises the delegated-access metadata only while the switch is on
- `34b4872c01` FR-OPS-2, FR-TOK-20: alert thresholds for delegated-access monitoring, one name for the caller
- `c36952cb43` FR-OPS-4, FR-OPS-5: the localdev fixture is the contract with the reference applications
- `dd28cc98be` FR-TOK-6, FR-TOK-19, FR-TOK-22, FR-TOK-24, FR-VER-2, FR-CEN-13, FR-CEN-16: the threat sweep, end to end
- `6ca9352f97` FR-OPS-1: discovery names the token exchange grant from the form that serves it
- `fbd913958c` FR-OPS-2: alert thresholds leave the application configuration

## How to review

Diff against `delegated-access-saml-assertions`. Check first: the presenter's off-state literal equals the document Login.gov publishes today, member for member and in order; the on-state members against RFC 8414 §2 and RFC 9449 §5.1; the fixture header against what the reference applications actually read. Then read the threat sweep as the integrated acceptance test. Specs: the presenter spec (11), the threat sweep (13), the seeder spec. Must not change for existing clients: with the switch off the discovery document is unchanged; the analytics rename touches only the three delegated-access events.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): `GRANT_TYPE` read from the form; the alert keys removed (plan 5.11 item 9).
- The browser client's scope names were out of contract with `token_exchange:housing_records` and `token_exchange:retirement_benefits`; the client is being corrected, not the fixture.
- The passport agency's direct-service-provider record for the `document_images_sharing` allow-list is not in the fixture (plan 5.12).
- The end-to-end review of `docs/attempts-api/schemas` is done on the fraud-signals branch, which owns the events.
- Four pre-existing environment failures in the full suite (three browser specs needing the sample service provider's port, one layout spec needing undigested asset names) are recorded here and recur on every branch above.

## Depends on / depended on by

Depends on everything below it that the discovery document names and the threat sweep calls: the exchange, lifecycle, introspection, SAML and DPoP branches, and the account-page controllers it renames a property in. Depended on by `delegated-access-billing-reporting`, `delegated-access-fraud-signals` and `delegated-access-config-content` by position; the config-content branch rewrites the fixture header's environment keying.
