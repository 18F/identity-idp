# Delegated access: human review stack

The reconstruction starts at main `063d69fc91` (2026-10-14), not at the prototype foundation. Review each pull request against its stated parent, in order. The branch prefix is `dcl/delegated-access/`; `dlh-woc` owns the reconstructed commits and PRs. Kyle Neuman, Tai Groot, and Davi/SgtPluck are credited with Co-authored-by trailers.

The source is the fourteen original PRs #13632–#13645, through `3121f14fe1`, including their document-image foundation and per-site-key prerequisites. Original PRs remain available for provenance. Agent-specific duplicated indexes and workflow scripts are not product changes and are not copied into this human review stack. Functional requirements remain in the source document, whose section numbers describe capabilities; the review manifest below owns the new merge order.

## Review contract

A disabled flag preserves main's accepted and ignored parameters, validation errors, authentication, persistence and response behavior. Check public, confidential and nullable client records. An enabled transaction retains its original security requirements after rollback; enabling a flag does not add requirements to an older transaction.

Review the entire path: authorization parsing, stored request/session, identity linkage, code redemption, userinfo, token exchange, refresh, revocation, introspection, billing and Attempts delivery. An authorization-only fix is insufficient.

## Corrections included

- Ignore inactive DPoP and site-key request parameters. Drop delegation and document-image scopes through the pre-feature scope parser when disabled.
- Save a trusted binding marker with an in-flight authorization request. Preserve it through consent and locale changes; missing markers identify legacy unbound requests. Browser parameters cannot set it.
- Bind code redemption and its token type to the saved DPoP thumbprint, not current registration. Preserve existing unbound families across registration changes.
- Verify durable family revocation at introspection so a late Redis write cannot reactivate access. Single-token revocation leaves its family usable.
- Re-check the application's accepted service providers at introspection.
- Apply the same continuing-approval rule to refresh and introspection after a new sign-in.
- Snapshot authentication time when opening a family; OAuth introspection and SAML renewal retain it.
- Preserve ordinary Redis request records without empty delegation metadata. Hide disabled navigation and new endpoints while preserving revocation of existing approvals.
- Preserve disabled token-endpoint errors and report shapes. Do not write delegated billing metadata for legacy direct sign-ins.
- Create the final delegation schema directly; omit the prototype create/drop migrations.

## Reading order and evidence

The completed manifest and verification record accompany the final stack review commit. Each preceding commit includes a focused changelog under `changes/`, its source attribution, and the exact changed files. Foundation PRs may prepare code before endpoint wiring; they are not separate feature releases.

## Data review

The authentication-time snapshot belongs to the existing narrow issuance record because it must survive browser sessions and renewals. It is a timestamp, not a token or identity attribute. Existing issuance revocation is authoritative; no new unbounded tombstone store is introduced. Refresh credentials remain digests with bounded retention and a pruning job. Billing adjustments remain append-only and issuer-based. New schemas and event shapes require data-team notification; notification is not yet recorded for this reconstruction.
