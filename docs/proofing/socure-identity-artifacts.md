# Delivering identity proofing artifacts (document + selfie images) to a relying party

Status: research / design draft
Branch: `proofing/socure-identity-artifacts`

## Problem

A relying party (RP) needs the identity artifacts produced during IAL2 proofing —
the captured ID document image(s) (DL / state ID / passport) and the selfie /
liveness portrait — for downstream adjudication. Every login (new or existing
account) must force a **fresh** proofing session so the artifacts are current.
**mDL flows must be exempt** because they skip artifact creation.

The Attempts API is the tempting source but is the wrong tool:

- It is scoped to **fraud investigations**, not RP data sharing.
- Retrieval is a **manual, human-in-the-loop** poll + decrypt + drop-in-Drive
  process — not programmatic per-user pulls.
- It emits events keyed by issuer/hour containing image **file IDs + AES keys**,
  not an on-demand per-user artifact fetch.

We want either (a) a way to hand the RP the identifiers needed to pull artifacts
from Socure directly, or (b) have Login.gov proxy the artifact fetch. Both most
likely require new OIDC scope(s)/claim(s).

## What exists in the codebase today (grounding)

### Socure DocV client
- `app/services/doc_auth/socure/requests/document_request.rb` — starts a DocV
  session; sends `customerUserId = current_user.uuid`, `documentType`,
  `useCaseKey` (selfie vs id-only). mDL sends `MDL_DOCUMENT_TYPE = 'digital_id'`.
- `app/services/doc_auth/socure/requests/docv_result_request.rb` — fetches
  results (`docvTransactionToken`).
- `app/services/doc_auth/socure/requests/images_request.rb` — GETs the zipped
  images from Socure by `reference_id`; `entry_name_to_type` maps
  `Doc_Selfie_1_blob.jpg → :selfie`, plus `:front/:back/:passport`.
- `app/services/doc_auth/socure/responses/docv_result_response.rb` — parses
  `referenceId`, `docvTransactionToken`, `customerProfile.customerUserId`
  (`DATA_PATHS[:socure_customer_user_id]`), selfie/liveness status.
- Identifiers persisted on `document_capture_session`:
  `socure_docv_transaction_token`, and the `reference_id` used for image pulls.

### Socure image retrieval + storage (already implemented!)
- `app/jobs/socure_image_retrieval_job.rb` → `DocAuth::Socure::Requests::ImagesRequest#fetch`
  → `Idv::IdvImages#write_with_data`.
- `app/services/idv/idv_images.rb` — writes front/back/passport/selfie via
  `EncryptedDocStorage::DocWriter` (AES-256, `Encryption::AesCipherV2`).
- `app/services/encrypted_doc_storage/{doc_writer,s3_storage,local_storage}.rb`
  — encrypted objects at `encrypted_images/<uuid>` in
  `IdentityConfig.store.encrypted_document_storage_s3_bucket`.
- Gated by `FeatureManagement.doc_escrow_enabled?` /
  `doc_escrow_s3_storage_enabled`. **90-day retention is an S3 lifecycle policy
  in infra/terraform, not app code.**

> Key insight: Login.gov **already retrieves and escrows the images** (the "doc
> escrow" path). That materially changes the design — we may not need Socure at
> serve time at all; we can serve from our own escrow.

### Socure's own artifact API (public docs)
- `GET https://riskos.socure.com/api/evaluation/{eval_id}/documents` → ZIP of
  `Doc_Front/Back/Selfie` blobs. Bearer API key auth.
- Retention: not a fixed public number; images are deleted for military IDs and
  minors immediately, otherwise per data-retention policy; `400 "No Documents
  Found"` when gone.
- Identifier needed is `eval_id` (their evaluation UUID); `referenceId` is for
  correlation. We track `reference_id` + `docv_transaction_token` today.

### Forced re-proofing (already exists — this is the "flag" you remembered)
- `app/policies/idv/service_provider_based_reproofing_policy.rb` —
  `#needs_to_reproof?`:
  - `reproof_forcing_sp?` → SP issuer == `IdentityConfig.store.reproof_forcing_service_provider`
    (and differs from initiating SP), **or**
  - `unsupervised_with_selfie_reproofing_required?` → SP in
    `IdentityConfig.store.reproof_if_not_unsupervised_with_selfie_service_providers`
    and current profile isn't a facial-match opt-in level.
- Requires the request to be facial-match (`resolved_authn_context_result.facial_match?`).
- Called from `openid_connect/authorization_controller.rb`, `idv_controller.rb`,
  `concerns/idv_session_concern.rb`.
- **Config-only** to force fresh proofing for the RP: set
  `reproof_forcing_service_provider` to the RP issuer. No code change needed.

### Facial-match / IAL2-bio request path
- `Component::Parser` + `AuthnContextResolver` derive `facial_match?` from ACR;
  `ServiceProvider#facial_match_ial_allowed?` gated by
  `facial_match_general_availability_enabled`.
- RP must request the IAL2-bio ACR to trigger selfie capture (and thus a selfie
  artifact). This is the RP-config lever, not code.

### mDL exemption
- `Idp::Constants::DocumentTypes::MDL = 'mobile_drivers_license'`;
  `document_capture_session.mdl_requested?` / `#request_mdl!`; gated by
  `idv_doc_auth_mdl_enabled_percent` + `ab_test_bucket(:DOC_AUTH_MDL)`.
- Any artifact-sharing path must **short-circuit when `mdl_requested?`** (no
  images captured to escrow / retrieve).

### OIDC attribute plumbing (where a new claim/scope goes)
- `app/services/openid_connect_attribute_scoper.rb` — `VALID_SCOPES`,
  `IAL2_SCOPES`, `ATTRIBUTE_SCOPES_MAP`, `filter`.
- `app/presenters/openid_connect_user_info_presenter.rb#user_info` — builds
  claims, merges `ial2_attributes` when
  `identity_proofing_requested_for_verified_user?`, then `scoper.filter`.
- `app/forms/openid_connect_authorize_form.rb` — per-SP scope authorization
  (`validate_privileges`, `identity_proofing_service_provider?`).
- SAML side: `service_providers.attribute_bundle`, `attribute_asserter.rb`.
- PII loaded via `OutOfBandSessionAccessor#load_pii(active_profile.id)`.

## Design options

All options share these already-solvable prerequisites (mostly config):
1. Force fresh proofing for the RP: set `reproof_forcing_service_provider` =
   RP issuer (existing policy).
2. RP requests IAL2-bio ACR so a selfie is captured.
3. Ensure `doc_escrow_enabled` is on so images are escrowed at proofing time.
4. Exempt mDL: guard all artifact exposure on `!mdl_requested?`.

### Option A — Login.gov proxies artifacts from its own escrow (recommended)

New OIDC scope, e.g. `identity_artifacts` (or `document_images`), that grants the
RP an **access-token-authenticated download endpoint**, not inline claims.

- userinfo (or a dedicated claim) returns short-lived, signed artifact URLs, e.g.
  `document_images: { front: <url>, back: <url>, selfie: <url>, passport: <url> }`
  where each URL hits a new controller
  `OpenidConnect::DocumentImagesController#show` authenticated by the same
  bearer access token (reuse `AccessTokenVerifier`).
- **Claim contract (three states the RP must handle):**
  - **Claim absent** — sharing is not authorized for this identity (scope not
    granted, SP not allow-listed, no/expired/stale consent, or not IAL2). Do not
    retry; nothing will appear.
  - **`document_images: {}`** — sharing is authorized but no artifacts are
    available yet. Image retrieval runs asynchronously after proofing and may
    land after the first userinfo call under worker backlog; the RP should
    retry userinfo (or the proxy URLs) with backoff. Also the steady state for
    mDL, which produces no shareable artifacts.
  - **`document_images: { <type>: <url>, ... }`** — artifacts are available;
    fetch each URL with the bearer access token.
- Alongside the images, userinfo returns a `document_metadata` claim with the
  document identifiers Socure captured — `document_number`, `document_issued`,
  `document_expiration` — released under the identical gate (same scope, consent,
  allow-list, ACR). These are small scalars so they are returned **inline** in
  userinfo (like SSN), not via the proxy. Same three-state contract: absent =
  not authorized, `{}` = authorized but not yet landed / mDL, populated = ready.
  These fields are **not** persisted into the core `Pii::Attributes` bundle
  (which would leak them to every proofing SP); they live in an encrypted
  `document_metadata` row on the same success-only, profile-linked, 90-day
  retention lifecycle as the images.
- The controller reads from the existing `EncryptedDocStorage` escrow (decrypt
  with the stored per-image AES key referenced by the profile/capture session),
  streams bytes, and audits every access.
- Pros: no live Socure dependency at serve time; artifacts already encrypted and
  retained 90 days; single trust boundary (RP ↔ Login); consistent whether the
  vendor was Socure or another; works for passport & DL.
- Cons: new endpoint + authZ + audit; need a durable link
  profile → escrowed image names/keys (today the file IDs/keys live in the
  Attempts event payload and the retrieval job's `image_storage_data`, so we need
  to persist a mapping — see "Open questions").
- Scope/claim wiring: add to `VALID_SCOPES`/`IAL2_SCOPES`, `ATTRIBUTE_SCOPES_MAP`;
  emit URLs in the presenter behind `identity_proofing_requested_for_verified_user?`
  and `!mdl`; authorize per-SP in `openid_connect_authorize_form`.

### Option B — Login.gov returns Socure identifiers; RP pulls from Socure

New claim(s) exposing `socure_eval_id` (+ maybe `reference_id`) so the RP calls
`GET /api/evaluation/{eval_id}/documents` with its own Socure credentials.

- Pros: least storage/serving work for Login; RP gets vendor-native ZIP.
- Cons: leaks vendor coupling to the RP; requires RP↔Socure contractual data
  access + API keys; Socure retention is shorter/less predictable than our 90-day
  escrow; breaks if vendor != Socure; military-ID/minor deletions cause gaps;
  we currently persist `reference_id`/`docv_transaction_token`, **not** the Socure
  `eval_id` — would need to capture/store it. Weakest option for adjudication
  reliability.

### Option C — Hybrid: Login proxies, sourced live from Socure on demand

Same RP-facing surface as A, but the proxy fetches from Socure at request time
(reusing `ImagesRequest`) instead of from escrow.

- Pros: no new persisted escrow mapping if escrow isn't already reliable.
- Cons: live vendor latency/availability on the adjudication path; subject to
  Socure retention/deletion; vendor-specific. Prefer A unless escrow coverage is
  insufficient.

## Recommendation

**Option A.** We already retrieve, encrypt, and (via S3 lifecycle) retain the
images for 90 days. Proxying from our own escrow behind a new OIDC scope gives
State a stable, vendor-agnostic, auditable channel and keeps all data-sharing
policy inside Login.gov. Fall back to C only if escrow coverage turns out to be
partial; avoid B for adjudication.

## Open questions / follow-ups (need answers before implementation)

1. **Escrow ↔ profile mapping (CONFIRMED GAP — the one required backend change).**
   The escrowed image object names + AES keys are **never persisted**. They are
   generated in `app/jobs/socure_docv_results_job.rb:189` (`image_storage_data`:
   `doc_escrow_name = "encrypted_images/#{SecureRandom.uuid}"`,
   `doc_escrow_key = Base64(SecureRandom.bytes(32))`), passed transiently as a job
   arg to `SocureImageRetrievalJob`, consumed by `Idv::IdvImages#write_with_data`
   to write the encrypted bytes, and otherwise emitted **only** as Attempts /
   FraudOps event metadata. No `db/schema.rb` columns and no `Profile` /
   `DocumentCaptureSession` association exist. Option A therefore requires
   persisting this mapping. Proposed shape (needs explicit approval — repo rules
   forbid unrequested schema/backend changes):
   - New table `proofing_document_artifacts` (or columns on the verified profile),
     rows keyed by `profile_id`, one per image type, storing: `image_type`
     (front/back/passport/selfie), `storage_name` (the `encrypted_images/<uuid>`
     path), `encryption_key` (Base64 AES-256 — **must itself be stored encrypted**,
     e.g. via existing KMS/`Encryption` helpers, not plaintext), `content_type`,
     `created_at`. Populate at the same point `image_storage_data` is finalized
     (post-retrieval), associating to the resulting verified `Profile`.
   - Deletion must be wired to the same 90-day lifecycle / profile-deactivation so
     DB rows never outlive the S3 objects.
2. **Legal basis / data-sharing agreement** for pushing biometric artifacts to a
   partner (privacy review, SORN, retention obligations on the RP side).
3. **Retention & deletion semantics** the RP must honor; do artifact URLs expire
   with our 90-day window?
4. **mDL confirmation** — verify `mdl_requested?` reliably reflects "no artifacts"
   for every mDL variant.
5. **Selfie guarantee** — confirm the RP's ACR always forces facial-match so a
   selfie artifact exists.
6. **Vendor abstraction** — should the claim be vendor-neutral now (it should,
   per Option A) to cover non-Socure DocV vendors?

## Concrete implementation sketch (Option A, when approved)

- Scope: add `document_images` to `OpenidConnectAttributeScoper` maps + per-SP
  authorization in `openid_connect_authorize_form.rb`.
- Presenter: in `openid_connect_user_info_presenter.rb`, when scope requested,
  proofed, and `!mdl`, emit signed URLs.
- Endpoint: `OpenidConnect::DocumentImagesController#show`, bearer-auth via
  `AccessTokenVerifier`, streams from `EncryptedDocStorage`, full audit logging.
- Persistence: profile→artifact mapping (schema change — requires explicit
  approval). Populate where `socure_docv_results_job.rb` finalizes
  `image_storage_data`; store `encryption_key` encrypted at rest; delete in lockstep
  with the 90-day S3 lifecycle and profile deactivation.
- Guard rails: feature flag, per-SP allowlist, mDL exemption, audit events.
- Tests: authorize-form scope authZ, presenter claim gating (proofed / mdl /
  non-facial-match), controller authN/authZ + audit, storage decrypt.
