# Data review for the reconstruction

## Summary

The stack adds application/resource registration, user approvals, bounded token-family records, encrypted document artifacts and site-key custody, plus billing adjustments and delegated Attempts events. The reconstruction removes obsolete prototype create/drop migrations and adds an immutable `authenticated_at` timestamp to the final token issuance table. A positive DPoP binding marker stays in the existing TTL-bound authorization-request cache; ordinary request JSON does not gain empty delegation metadata.

## Decision

Suitable for draft human review, subject to the verification record and data-team review. This is an engineering assessment, not data-team approval or release authorization. A failed or unverified disabled-mode contract blocks release.

## Findings

1. Keep `authenticated_at` on the issuance record: renewal and introspection need the original authentication event after the browser session ends. Reading the mutable identity connection would report a later sign-in instead.
2. Durable issuance revocation must remain authoritative over Redis publication. A late cache write must not resurrect a revoked family. Revoking one access token removes that token, not all siblings in its family.
3. Keep billing adjustments append-only and at the existing issuer/agreement grain. Existing `NULL` access types retain their meaning; disabled direct sign-ins continue writing `NULL`. Extra CSV and JSON breakdowns are opt-in. The source document's billing fallback and reconciliation questions remain open in Appendix D.
4. Preserve existing analytics payloads when features are inactive. Optional delegation and encryption fields are omitted rather than introduced as empty or false values. New Attempts event schemas are additive; agency delivery requires the feature, delivery, enrollment and consent checks.
5. Do not infer a transaction's binding from a previously ignored request parameter. Only the trusted saved marker and subsequently saved thumbprint establish that requirement. Legacy records without a marker remain unbound when a flag changes.

## Persistence assessment

| State | Storage and purpose |
|---|---|
| Application and API configuration | Durable registry records; needed for onboarding, allowlists and current policy checks. |
| User approval and content versions | Durable approval records; needed for revocation, remembered consent and content changes. |
| Issuance and original authentication time | Narrow durable family record; required after browser-session expiry. Existing `revoked_at` is the revocation authority. |
| Refresh credentials | Digests in bounded family records, with rotation/reuse state and expiry cleanup. Raw refresh tokens are not persisted. |
| Delegated access tokens | TTL-bound Redis entries; no new durable raw-token column. |
| Authorization binding decision | Positive marker in the existing request cache and its TTL; absent for legacy/unbound transactions. The browser cannot supply it. |
| Billing evidence | Existing return logs plus append-only adjustments; no mutation of historical invoice evidence. |
| Document artifacts and site-key roots | Encrypted custody and narrow metadata from the prerequisite changes; inspect their separate review units. |

## Sensitivity assessment

Browser DPoP private keys are not sent to Login.gov. Public thumbprints and boolean binding markers are not secrets. Authentication timestamps, approval records and user identifiers are linkable operational metadata and retain the existing restricted data-handling requirements; a migration annotation is not a claim that the data is public. Document images and site-key roots require encrypted storage and controlled release. Tokens, decrypted images and key material must not enter ordinary analytics or report output.

## Analytics and Attempts assessment

The unchanged direct path must keep its pre-feature event shape. New fields belong to active feature events only. Delegated agency copies remap the subject, include the delegation/actor identifiers, and use the recipient's configured encryption key. Review schema changes alongside the runtime event tests and the analytics/tracker lint results in the verification record.

## Data team notification

Required for the new tables, cache state, event schemas and billing/report changes. No notification or approval is claimed for this reconstruction. The draft PRs make the proposed changes reviewable; downstream modeling and deployment approval remain follow-up work before release.

## Required tests and guardrails

Review disabled-mode request acceptance and persisted JSON against main; exercise authorization before and after a policy change, code redemption, userinfo, refresh, introspection and revocation. Verify revocation/publication races, original authentication time, allowlist withdrawal, default report shapes, and direct billing metadata. Verify migrations from main's schema, event documentation, and secret scans. See the verification record for measured outcomes rather than the source stack's historical test counts.
