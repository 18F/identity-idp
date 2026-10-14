# NIST SP 800-63-4 compliance analysis — document-image sharing to relying party

Status: compliance review / draft
Companion to: `docs/proofing/socure-identity-artifacts.md`
Scope: the `document_images` OIDC scope + proxy endpoint that delivers escrowed
ID-document and selfie/liveness images to a relying party (RP) for adjudication.

> Bottom line: the identity **proofing** remains IAL2-conformant (unchanged
> process, strengthened by forced re-proofing + facial match). The **artifact-
> sharing feature** as currently built would likely produce adverse findings in
> an SP 800-63-4 assessment — primarily biometric use-limitation, attribute
> minimization, and purpose-specific consent — until the controls in
> "Required remediations" are in place. Do not enable in production before then.

## Applicable requirements (SP 800-63-4 family)

- **SP 800-63-4 (base)** — privacy, data minimization, use limitation, redress.
- **SP 800-63A-4 (Identity Proofing & Enrollment)** — biometric collection,
  **use limitation / purpose specification**, retention, and disposal of
  proofing evidence and biometrics.
- **SP 800-63C-4 (Federation & Assertions)** — attribute minimization, consent
  and notice before attribute transmission, protection of assertions and
  attributes, preference for derived/pairwise values over raw data.
- Supporting: SP 800-53 (AC, AU, SC, IA control families) for the endpoint;
  agency privacy obligations (PIA, SORN, NARA retention schedule).

> Section numbers should be verified against the final published text before
> this document is used for an assessment; requirements below are stated by
> theme and volume.

## Findings

### 1. Biometric use limitation — PRIMARY RISK (800-63A-4)
Biometrics (selfie / liveness portrait) collected during proofing may only be
used for the purposes disclosed at collection: identity proofing, fraud
mitigation, and re-proofing. Our encrypted doc escrow (90-day S3 lifecycle)
exists for fraud / re-proofing. Feeding those images to an RP is a **new,
undisclosed purpose**. This is the largest exposure and cannot be resolved by
engineering alone — it requires disclosed purpose + consent + authority.

### 2. Attribute minimization (800-63C-4)
Federation guidance requires transmitting the **minimum** attributes necessary
and prefers derived/boolean claims (e.g. "verified: true") over raw data.
Shipping full raw ID-document and selfie imagery is the opposite. If raw images
are genuinely required for passport adjudication, that necessity must be
documented and justified; otherwise a derived assertion should be used.

### 3. Consent & notice (800-63C-4 + base privacy)
Explicit, purpose-specific consent and notice are required before attribute
transmission, with heightened treatment for biometrics. Today the code captures
only a **generic scope-level consent** on the agency handoff
(`app/controllers/sign_up/completions_controller.rb` →
`sp_user_consent_granted`; `verify_sp_attributes_concern.rb` →
`last_consented_at`). Reusing that generic flow for biometric imagery is
insufficient. A distinct, biometric-aware consent is required.

### 4. Retention & disposal (800-63A-4)
Retention must be tied to the specified purpose with documented disposal. The
shared-artifact channel currently relies on the fraud-escrow S3 lifecycle, which
was justified for a different purpose. The sharing feature needs its own
documented retention schedule and disposal path (independent of the fraud
escrow), and DB rows must never outlive the underlying objects.

### 5. CSP change control / re-assessment
Adding a biometric-sharing channel is a material change to the CSP. It triggers
re-assessment against 800-63-4 and updates to the CSP practices/conformance
documentation, and likely PIA/SORN review.

## What the current design gets RIGHT (retain these)
- Login.gov **proxies** artifacts rather than exposing the vendor (Socure) to
  the RP — single trust boundary.
- Artifacts encrypted **at rest** (AES-256 via `EncryptedDocStorage`), key stored
  encrypted (`DocumentArtifact#encryption_key` via KMS-backed encryptor).
- Access gated by a **scoped bearer access token** at a dedicated endpoint
  (`OpenidConnect::DocumentImagesController`) with per-SP scope authorization.
- **mDL exemption** — no artifacts created/shared for mDL flows.
- Vendor-neutral claim shape (works beyond Socure).
- These satisfy the 800-63C protection-in-transit/at-rest and 800-53 SC/AC
  themes; the mechanism is not the problem.

## Required remediations (gate for production)

1. **Purpose-specific biometric consent** — a dedicated consent screen (not the
   generic scope handoff) that names the RP (State), the exact artifacts shared,
   the purpose (DS-11 passport adjudication), and retention. Record a distinct
   consent event separate from `sp_user_consent_granted`; block release without
   it.
2. **Legal authority & agreements** — executed data-sharing / interconnection
   security agreement (ISA) with State; confirmation of statutory authority to
   disclose biometrics for passport adjudication.
3. **Minimization justification** — document why raw images (rather than a
   derived pass/fail) are necessary; restrict the `document_images` claim to the
   specific RP via allowlist + feature flag.
4. **Independent retention & disposal** — a documented retention schedule for
   shared artifacts, with disposal not borrowed from the fraud-escrow lifecycle.
5. **Assessment & documentation deliverables** (none exist in-repo today):
   - Privacy Impact Assessment (PIA) — new/updated.
   - System of Records Notice (SORN) — update (currently only prose reference).
   - NARA records retention schedule for shared artifacts.
   - CSP practices statement / 800-63-4 conformance addendum for the channel.
   - 800-63C attribute-assertion documentation for the `document_images` claim.
6. **Redress & transparency** — subscriber-facing record of what was shared and
   with whom (aligns with base-volume redress/privacy).

## Implementation status (this branch)

Code-level remediations now in place (gate is enforced in three layers):

- **Feature flag + per-SP allowlist** — `document_images_sharing_enabled` and
  `document_images_sharing_service_providers`
  (`ServiceProvider#document_images_sharing_allowed?`). Default off / empty.
- **Purpose-specific biometric consent** — recorded distinctly from generic
  scope consent on the agency handoff
  (`identities.biometric_sharing_consent_at`, set in
  `VerifySpAttributesConcern#update_verified_attributes` only when the SP is
  allow-listed and `document_images` is requested; disclosure copy on the
  completions screen; `biometric_sharing_consent_granted` analytics event).
- **Release gating** — both the userinfo claim
  (`OpenidConnectUserInfoPresenter#document_images_shareable?`) and the proxy
  endpoint (`OpenidConnect::DocumentImagesController`) require: verified profile,
  `document_images` scope, SP allow-listed, and consent granted. mDL profiles
  have no artifacts.
- **Consent integrity** — consent is only recorded from an affirmative checkbox
  (server-enforced; an unchecked/stripped submission re-renders with an error);
  it is set-or-cleared at each handoff; it expires after 1 year and is
  invalidated by any newer proofing; and the handoff screen re-prompts
  (`:biometric_consent_needed`) whenever an allow-listed SP requests the scope
  without current consent.
- **Artifact integrity** — artifacts are persisted only for a *successful*
  verification, and stale artifacts from earlier failed attempts on the same
  capture session are pruned, so images of a rejected document can never be
  shared. Artifacts are linked to their profile **deterministically**:
  `Idv::Session` stamps `document_capture_sessions.profile_id` with the exact
  profile a session produced, and the retrieval job reconciles only from that
  stamp (re-read from the DB) — never by timestamp or "current active profile",
  so one session's images can never attach to another session's profile. Both
  sides take a `FOR UPDATE` row lock on the capture session so they serialize
  under worker backlog. A stale job (superseded by a redo that started a newer
  Socure transaction) self-cancels via a transaction-token check. In-person
  verified profiles are never stamped or linked: the identity was established by
  the USPS visit, not by remote images from an abandoned attempt.
- **Retention** — `document_images_retention_days` (default 90, matching the
  escrow S3 lifecycle) drives a `retained` scope used at both the userinfo and
  proxy layers, plus a daily `ExpireDocumentArtifactsJob` that deletes aged rows
  (and their wrapped keys) so DB rows never outlive the S3 objects.
- **Key durability** — per-image AES keys are wrapped with the rotatable
  `AttributeEncryptor` (old-key queue), not a session-scoped encryptor.
- **Audit** — every proxy request emits `document_image_release` (success or
  denial reason, image type, issuer, profile).

Still required before production (process/legal, not code):

- Legal authority + ISA with the RP (item 2).
- Minimization justification for raw imagery vs. derived assertion (item 3).
- Independent retention/disposal schedule (item 4).
- PIA / SORN / NARA schedule / CSP conformance addendum (item 5).
- Subscriber-facing redress record (item 6).

## Recommendation
Keep the feature behind the flag + allowlist (both default off) and treat the
remaining process/legal items as blocking prerequisites. Prefer a derived
assertion if adjudication can accept it; if raw imagery is truly
required, proceed only with documented purpose, biometric-specific consent,
legal authority, and an independent retention schedule, then re-assess against
800-63-4 before enabling.
