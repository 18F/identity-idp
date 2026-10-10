# delegated-access-consent

## Purpose

Plan 5.2, authorize request and the consent screen. The service provider names applications in the request as `token_exchange:<scope value>`; Login.gov refuses unknown or unaccepted ones at authorize, shows the requested applications selected and locked on the completions screen, records one approval per application, and lists the approved values in the token response `scope`. It replaces the foundation's consent over already-connected applications and removes the bare `token_exchange` attribute scope whose side effect skipped the screen.

## Requirements it satisfies

FR-CEN-1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 17; FR-CUX-1 to FR-CUX-11. Companion §4.1–§4.6 (CON-1..19 as amended in §4.8 and §4.9, CON-21).

## What it adds / removes and why

Adds:
- `OpenidConnectAttributeScoper.delegation_scope?`/`#delegation_scope_values` keep `token_exchange:*` values through parsing without adding them to attribute scopes; `OpenidConnectAuthorizeForm#validate_delegation_scopes` answers `invalid_scope` (`delegation_not_allowed`, `unknown_delegation_scope`) for a service provider not approved, a request that is not identity-verified, or an application not in `DelegationApplications.accepting` (D14, D15). Values travel in `sp_session[:requested_delegation_scopes]`; a SAML request has none.
- `VerifySpAttributesConcern#delegation_consent_needed?`: the screen is shown when any requested application lacks a remembered, current approval or a material content change postdates it (D9), once per authorization keyed by a SHA-256 of the authorize URL (fresh `state`/`nonce` make each authorization distinct).
- `_delegation_consent.html.erb`: service provider card, agency-grouped locked rows (`check_box_tag` checked and disabled, `aria-describedby`), `new`/`already approved`/`updated` badges (D17), the "Remember my approvals for 12 months" checkbox unchecked (D6), the access-duration sentence (D53). Cancel is the existing `return_to_sp_cancel_path`, returning `access_denied` (D13). The server approves what the session recorded, never a submitted list.
- `TokenExchangeConsent`: `TokenExchangeGrant.approve!` per application needing approval (`source: consent_screen`, three content versions, `remember_until` or `rails_session_id`, `proofed_in_session`); a remembered, current pre-approval is kept untouched (D16).
- `OpenidConnectTokenForm#granted_scope`: attribute scopes plus the approved `token_exchange:*` values valid for this authorization (FR-CEN-9); unchanged when none was requested.
- Reuse review: `TokenExchangeGrant.partition_current` (one query, `{kept:, needing_approval:}`) read by the concern, the service and the account page; `OpenidConnectAttributeScoper.new(scope, allowed:)` parses once; `#current_authorization?(identity:)` takes a loaded identity.

Removes:
- `token_exchange` from `IAL2_SCOPES`, `ATTRIBUTE_SCOPES_MAP`, `CAPABILITY_SCOPES`: it named no application and, written to `verified_attributes`, suppressed the screen for a year.
- "Allow all linked" and "auto-enroll" controls, the per-application choice and its TypeScript pack (`delegation-consent.ts`): requested applications are not optional (D5).
- `TokenExchangeReachableTargets.linked_for` and `record_token_exchange_decision`/`auto_enroll_token_exchange` in the concern: the request defines the screen, the registry defines the account page.
- `sign_up.token_exchange_grant.*` strings.

## Key decisions

- D5 take-it-or-cancel (reverses the earlier per-application decline; no declines are recorded); D13 cancel returns `access_denied`.
- D14 `invalid_scope` for a non-identity-verified request; D15 OIDC service providers only (SAML stays an agency-side token format).
- D16 the remember choice never downgrades an existing remembered approval; D17 "updated" badge after a material change; D18 no content history table.
- D53 one sentence on access duration (up to 12 hours); nothing about fraud signals on the screen.

## Key files

Models: `app/models/token_exchange_grant.rb` (`live_by_application`, `partition_current`, `current_authorization?`), `app/models/federated_protocols/oidc.rb`, `app/models/federated_protocols/saml.rb`, `app/models/service_provider_request.rb`.
Forms: `app/forms/openid_connect_authorize_form.rb`, `app/forms/openid_connect_token_form.rb` (`granted_scope`).
Services: `app/services/token_exchange_consent.rb`, `app/services/openid_connect_attribute_scoper.rb`, `app/services/delegation_applications.rb`, `app/services/store_sp_metadata_in_session.rb`, `app/services/service_provider_request_proxy.rb`, `app/services/analytics_events.rb` (`delegation_consent_submitted`).
Controllers/views: `app/controllers/concerns/verify_sp_attributes_concern.rb`, `app/controllers/sign_up/completions_controller.rb`, `app/presenters/completions_presenter.rb` (`delegation_groups`), `app/views/sign_up/completions/_delegation_consent.html.erb`, `app/views/sign_up/completions/show.html.erb`, `app/decorators/service_provider_session.rb`.
Migrations: none.
Specs: `spec/features/openid_connect/delegated_access_consent_spec.rb` (Bullet on), `spec/forms/openid_connect_authorize_form_spec.rb`, `spec/forms/openid_connect_token_form_spec.rb`, `spec/services/token_exchange_consent_spec.rb`, `spec/services/openid_connect_attribute_scoper_spec.rb`, `spec/presenters/completions_presenter_spec.rb`, `spec/models/token_exchange_grant_spec.rb`.
Config/locales: `config/locales/{en,es,fr,zh}.yml` (`sign_up.delegation.*`).

## Commits

- `881c0dda9b` FR-CEN-1, FR-CEN-2, FR-CEN-3: request applications by delegation scope on the authorize request
- `a83e605e84` FR-CUX-1 to FR-CUX-11, FR-CEN-5/6/7/11/17: consent screen for requested applications
- `833d54f710` FR-CEN-9: token response scope lists the approved delegation scopes
- `6919e5ac8c` FR-CEN-1: delegation scopes enter the SP session only when requested
- `9dde8e0ffd` FR-CUX-2: consent screen states how long the service provider's access lasts
- `057d2b5ce1` FR-CEN-11, FR-CUX-13: one partition of requested applications into kept and needing approval
- `502b8900f2` FR-CEN-1: the authorize form reads delegation scopes through OpenidConnectAttributeScoper
- `527e34d11d` FR-CEN-9: a loaded identity answers whether a single-authorization approval is current

## How to review

Diff against `delegated-access-registry`. Check first: `validate_delegation_scopes` (what is refused and with which code), `delegation_consent_needed?` and the once-per-authorization marker, that the submitted form carries no application list the server trusts, and `granted_scope`. Specs: the feature spec (locked rows, cancel to `access_denied`, remembered skip, request growth, material change, `invalid_scope`), the two form specs, the consent service spec. Must not change for existing clients: a request without `token_exchange:*` parses, consents and returns `scope` exactly as before; delegation values never enter `requested_attributes` or `verified_attributes`.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): items 9 to 11 of plan 5.2 (partition, single parse, loaded identity).
- Declines no longer exist as records (plan 5.2 Findings 1); the outcomes report counts `withdrawn_before_use` instead (D68).
- The approved mockup needs a revision for the locked, disabled checkbox (plan 5.2 Findings 2).
- The fraud-signals branch adds `record_delegation_consent` release hooks into this concern and controller.

## Depends on / depended on by

Depends on `delegated-access-registry` (applications, grants, `DelegationApplications`). Depended on by `delegated-access-account-page` (shared partials and `partition_current`), the token-exchange branch (grants to check, `rails_session_id` for single-authorization approvals), the DPoP branch (the feature spec signs in as a key-bound public client) and the fraud-signals branch (release at consent).
