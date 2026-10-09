# Review of `18F/identity-idp` branch `sbx-taigrr` against the functional requirements, and the plan for `login-delegated-access`

**Date:** 2026-10-09 (supersedes the 2026-10-05 review)
**Authoritative copy:** `docs/delegated-access-implementation-plan.md` on branch `login-delegated-access` of `identity-idp`, together with `docs/delegated-access-functional-requirements.md` and `docs/delegated-access-requirements.md`. The Google Drive copies are no longer maintained (decided 2026-10-09).
**Branch reviewed:** `sbx-taigrr` at `0b0539e19` (2026-10-08). Identical on GitHub `18F/identity-idp` and GitLab `lg/identity-idp`. Local clone: `/Users/kylepneuman/coding/worktrees/sbx-taigrr`.
**Compared against:** *Login STS and Dept of State Functional Requirements* (FR-… identifiers below), *Delegated Access for Login.gov — Requirements* (`delegated-access-requirements.md`, §-references below), and the `token-exchange2-login` branch on GitLab `lg/identity-idp` at `bd32c5f4e2` (2026-10-08), which implements those requirements against an older `main`.
**Purpose of this revision:** define the new branch `login-delegated-access`, which starts from `sbx-taigrr` and is extended feature by feature until it meets the functional requirements. For each feature the document states what the branch already has, what is added, what is removed and why, what engineering decisions remain, and what can be ported from `token-exchange2-login`. The last sections cover cross-cutting concerns and the sandbox infrastructure.

Nothing in this document has been implemented. Each feature waits for a go-ahead.

---

## 1. What changed since the 2026-10-05 review

1. `sbx-taigrr` gained one commit on 2026-10-08, "Add document metadata (number, issue/expiration) to document image sharing" (`0b0539e19`, 21 files). It persists the document number and issue and expiration dates Socure captures as an encrypted `document_metadata` row, on the same lifecycle as the document images, and returns them inline in userinfo under the same `document_images` scope, consent and allow-list. The branch is now 15 commits, 91 files, about 6,200 lines added, with 206 new spec examples.
2. `token-exchange2-login` on GitLab gained two commits by Ambuj Neupane on 2026-10-08 that add `docs/delegated-access-billing-strategy.md`. It is a review of the billing design that recommends never mutating `sp_return_logs`, dropping the `identity_id`, `actor_issuer`, `resource_server_identifier` and `delegated_proofing` columns, correlating the service provider's sign-in to a later exchange through a short-lived cache keyed by the digest of the subject token, and recording the waiver as a row in a new append-only `sp_return_log_billing_adjustments` table that invoice reports exclude with an `EXISTS` clause. Section 5.8 (billing) adopts most of it and lists the points that still need a decision.
3. `main` moved to `42e6a7171` (2026-10-08), ten commits past the point `sbx-taigrr` branched from. Section 2 lists the one conflict.
4. GitLab `lg/identity-idp` is a pull mirror of GitHub `18F/identity-idp` (project setting `mirror: true`, all branches, diverged branches overwritten). GitHub is the source of truth. `sbx-taigrr`, `token-exchange` and `main` have the same heads on both; `token-exchange2-login` exists only on GitLab because it was pushed there directly. This matters for the sandbox (section 7).

---

## 2. Reconcile `sbx-taigrr` with `main` first

`sbx-taigrr` branched from `main` at `827da132a` (2026-10-02). `main` is now at `42e6a7171` (2026-10-08), ten commits later:

1. `b9aa4456e` LG-17950 Discontinue photo retrieval job for mDLs
2. `62cf38755` LG-17765 Clear POC mint profile
3. `e1ce39607` LG-17948 Capture back of Passport Card in LN flow
4. `75f8a5536` LG-17896 Redirect DocV user with undetected mDL to Choose ID Type screen
5. `2aa7400d8` Stop specs from deleting the global form-action CSP directive
6. `557cdf126` Add sp request_id to CloudWatch events
7. `caea33b2e` Add document_type_received to analytics
8. `19c0d725d` Add vendor cost attribution
9. `80720e420` Update proofing agent api validation
10. `42e6a7171` Add logging to recaptcha failures for password reset and email confirmation

Twelve files were changed by both `main` and `sbx-taigrr` in that window: `app/jobs/socure_docv_results_job.rb`, `app/jobs/socure_image_retrieval_job.rb`, `app/services/analytics_events.rb`, `app/services/idv/session.rb`, `config/application.yml.default`, `lib/identity_config.rb`, the four locale files, `spec/jobs/socure_image_retrieval_job_spec.rb` and `spec/services/idv/session_spec.rb`. A dry-run merge (`git merge-tree`) auto-merges eleven of them and reports one textual conflict:

**`spec/jobs/socure_image_retrieval_job_spec.rb`.** Both branches add a new `context` block at the same place (after the existing failure cases). `main`'s commit `b9aa4456e` adds the test for the new early return `return if document_capture_session&.mdl_requested?` in `SocureImageRetrievalJob`. `sbx-taigrr` adds the "persisting document artifacts" context (artifact rows, encrypted metadata, profile linkage). Resolution: keep both blocks. There is no semantic conflict: `main` stops the job for mDL before anything runs, and `sbx-taigrr`'s `persist_document_artifacts` already skips mDL sessions, so the mDL behavior is the same with both changes present.

Two auto-merged files deserve a read after the merge rather than trust:

1. `app/jobs/socure_docv_results_job.rb`: `main` adds `&& !docv_result_response.document_type_mdl?` to the condition that schedules image retrieval; `sbx-taigrr` extends the job arguments in the same block (`persist_artifacts`, `docv_transaction_token`, `document_metadata`). Both apply cleanly and are compatible.
2. `app/jobs/socure_image_retrieval_job.rb`: `main`'s early return for mDL lands above `sbx-taigrr`'s new `persist_document_artifacts` call. Compatible.

Recommended first step on `login-delegated-access`, before any feature: merge `main` (`42e6a7171`) into it, resolve the one spec conflict as above, run the two Socure job specs and the IdV session spec, and commit. Every later feature then builds on current `main`. This also means the ten `main` commits reach the sandbox with the branch, which is the normal state for a sandbox environment.

**Done 2026-10-09.** Merged as `f77e9bce28` on `login-delegated-access` (GitLab), conflict resolved as above; the three specs both branches touch pass (170 examples). One extra commit, `c8d6f0cf1b`, changes `config.add(:lexisnexis_threatmetrix_hybrid_handoff_policy, :string, …)` to the `type:` keyword that identity-hostdata v4.4.2 requires; without it the app does not boot locally on this branch, exactly as `token-exchange2` found on 2026-09-28. `main` carries the same positional call and its GitLab pipeline passes, which is unexplained and worth asking the team about. The twelve feature worktrees were fast-forwarded to the merged head.

For reference, `token-exchange2-login` against the same `main` conflicts in two files, `app/forms/openid_connect_token_form.rb` and `db/schema.rb`. Neither matters for the plan because nothing is merged from that branch wholesale; pieces are ported (section 5).

---

## 3. The two branches side by side

### 3.1 What `sbx-taigrr` is

The branch is the National Design Studio `token-exchange` branch plus later commits (target opt-in, per-application grants, account-page toggles), merged with a `proofing/socure-identity-artifacts` branch that adds identity-document image and metadata sharing.

It is a different design from the functional requirements rather than a partial implementation of them. Its design document (`docs/token-exchange.md`) describes a **browser-callable** RFC 8693 exchange, **with no client secret**, that mints a **full user access token for the target service provider**, structurally identical to one the user would have received by signing in there directly, whose lifetime is the service provider's Rails session. Consent is per *application the user has already connected to*, not per agency API the service provider requests. The `document_images` scope lets an allow-listed service provider download the ID document photos and the selfie over a bearer-token URL and read the document number and dates from userinfo. The branch calls the service provider the "broker" in code, comments, strings and its design document; this document says *service provider*, and every identifier that carries the old word is renamed or removed by the feature that touches it (5.1, 5.2, 5.3).

Components:

1. `POST /api/openid_connect/exchange` (`OpenidConnect::ExchangeController`, `OpenidConnectTokenExchangeForm`), with a CORS rule in `config/application.rb` so browsers can call it.
2. A `token_exchange` scope, honored only for service providers listed in the `token_exchange_service_providers` JSON key of `application.yml`, treated as an IAL2 attribute scope so it flows through `requested_attributes`.
3. Target opt-in: `service_providers.allowed_token_exchange_brokers` (string array column).
4. `token_exchange_grants` (one row per user, service provider issuer, target issuer; 12-month expiry; revoke-not-delete) and `token_exchange_broker_settings` (auto-enrollment of future targets).
5. Consent control on the existing completions screen: "allow across all linked agencies", "automatically enroll new agencies", or pick specific linked applications grouped by agency (client-side paginated).
6. Account page: per-application on/off toggles and an auto-enroll toggle under the service provider's connected-app entry, with a confirmation modal.
7. Billing: an `SpReturnLog` row for the target at mint, billable once per (user, target, service provider session) through a deterministic `request_id`.
8. Attempts API: one `token-exchange-login-completed` event to the target at mint, carrying `broker_issuer`.
9. `id_token` for the target carries an RFC 8693 `act` claim naming the service provider; no `nonce`, no `c_hash`.
10. `document_images` scope, `document_artifacts` and `document_metadata` tables, `GET /api/openid_connect/document_images/:type` bearer-authenticated download, biometric consent checkbox on the completions screen, `ExpireDocumentArtifactsJob`, two design documents under `docs/proofing/`.

### 3.2 What `token-exchange2-login` is

Forty-one commits (160 files, about 11,800 lines added, 326 new spec examples) implementing the requirements document end to end against `main` at `48a1ff3e3f` (2026-09-04): onboarding data model, `token_exchange:<name>` scopes and the agency-level consent screen, Account → Delegated access, RFC 8693 exchange at the existing token endpoint with `private_key_jwt`, opaque delegated tokens with refresh rotation and RFC 7009 revocation, RFC 7662 introspection authenticated by the agency, Attempts buffering and delivery, billing rows and reports, SAML assertions as an issued token type, DPoP, discovery metadata, suspension and deletion cascade. It has only ever run locally, with the three reference applications and the live end-to-end harness (24 scenarios passing on 2026-10-08).

### 3.3 Where they collide

Twenty-eight files are changed by both branches relative to their bases. A dry-run merge of `token-exchange2-login` into `sbx-taigrr` conflicts in seventeen: `app/forms/openid_connect_token_exchange_form.rb` (both add it), `app/forms/openid_connect_token_form.rb`, `app/models/token_exchange_grant.rb` (both add it), `app/presenters/openid_connect_user_info_presenter.rb`, `app/services/analytics_events.rb`, `app/views/accounts/_connected_app.html.erb`, `app/views/sign_up/completions/show.html.erb`, `config/application.yml.default`, `config/initializers/job_configurations.rb`, the four locale files, `config/routes.rb`, `db/schema.rb`, `lib/identity_config.rb`, `spec/models/token_exchange_grant_spec.rb`. The branch is therefore built by porting, not merging.

Name collisions that must be resolved deliberately, because the same name means different things on the two branches:

1. **Table `token_exchange_grants`.** `sbx-taigrr`: `(user_id, broker_issuer, target_issuer, granted_at, expires_at, revoked_at)`, one row per application. `token-exchange2`: `(identity_id, token_exchange_scope_id, delegation_id, status, scope_content_version, sp_content_version, consented_at, remember_until, rails_session_id, proofed_in_session, first_exchanged_at, revoked_at, revocation_reason)`, one row per consent decision per API. The decided shape (section 9, D8) is one row per (user, service provider, application), closer to `sbx-taigrr`'s key with new columns. The sandbox database already has `sbx-taigrr`'s table, so the new branch's first migration drops it before creating the new one (nothing is kept for compatibility; neither branch is in production).
2. **Class `TokenExchangeGrant`** and **class `OpenidConnectTokenExchangeForm`**: different responsibilities on each branch.
3. **Scope string.** `sbx-taigrr` uses the bare scope `token_exchange` as an IAL2 attribute; `token-exchange2` uses `token_exchange:<scope_value>` per API. The bare value never matches the prefixed form, so the two could coexist, but the bare scope's side effect (it is written to `identities.verified_attributes`) is the cause of the remembered-decline bug below and must go.
4. **Config key `token_exchange_enabled`**: same meaning on both (master switch). Keep.
5. **Config key `token_exchange_service_providers`** (`sbx-taigrr`, JSON allow-list of service providers) against column `service_providers.token_exchange_enabled_sp` (`token-exchange2`). FR-ONB-9 and §3 ONB-5 require the SP-configuration path. Decision in 5.1.
6. **Analytics event `openid_connect_token_exchange`**: both define it with different properties.
7. **Attempts event `token-exchange-login-completed`** (`sbx-taigrr`) against the delegated event family in `token-exchange2` (`delegation-consented`, `delegated-token-issued`, `delegated-token-refreshed`, `delegated-access-revoked`, with `delegation_id`).
8. **Locale keys** `sign_up.token_exchange_grant.*` and `account.connected_apps.token_exchange.*` (`sbx-taigrr`) against `sign_up.delegation.*` and `account.delegated_access.*` (`token-exchange2`).
9. **`ServiceProvider#token_exchange_broker_allowed?` / `#allows_token_exchange_broker?`** against `#delegation_service_provider?` and the resource-server associations.

### 3.4 What to keep from `sbx-taigrr` regardless of feature

These pieces do not conflict with the premise of any requirement and are kept, in some cases generalized:

1. **Agency opt-in to specific service providers** (`allowed_token_exchange_brokers`). It answers the open question in functional requirements section 3, question 3 ("should an agency be able to restrict which service providers may use its APIs"). It moves from "target SP" to "agency SP that owns resource servers" and is enforced at authorize (FR-CEN-2) and at exchange.
2. **IAL forwarded, never elevated** (FR-FIT-5). `token-exchange2` copies `ial` and `aal` onto the delegated token; the same rule.
3. **The `act` claim naming the service provider** (FR-VER-3). `token-exchange2` returns it from introspection and as a SAML attribute.
4. **Analytics on every decision** (FR-OPS-2), renamed to the new vocabulary.
5. **Refusing to describe target-side errors until the caller has cleared its own gates** (audience probing). Carried into the exchange form.
6. **Document image and metadata sharing for a service provider the user signs in to directly** (section 5.12). It is a separate feature with its own flag and allow-list and is left in place.
7. **mDL exemption** for image sharing.
8. **Per-application toggles on the account page.** The pattern (a toggle per application under the service provider, confirmation before turning one on) is kept; what changes is the list, which becomes every registered application that accepts the service provider rather than the applications the user has connected to (section 9, D4).
9. **One consent choice per application, grouped by agency.** `sbx-taigrr`'s screen already works at application granularity, which is the granularity decided on 2026-10-09 (D1); the functional requirements move from agency-level to application-level consent.

---

## 4. Approach for `login-delegated-access`

1. Start from `sbx-taigrr` `0b0539e19`, merge `main`, then add features in the order of section 5. Each feature is one worktree and one branch (`lda-NN-<name>`), stacked on the one before it (section 8), and fast-forwarded into `login-delegated-access` when accepted.
2. Add only what a feature's functional requirements need. Remove only what contradicts the premise of that feature, and say so in the commit message in plain terms (for example: "the exchange is server-to-server, so the browser-callable endpoint and its CORS rule are removed").
3. Port from `token-exchange2-login` wherever the piece was tested there: models, forms, services, specs. Porting is by hand (the files conflict), commit by commit where a commit is self-contained. Comments stay functional and cite RFC sections, never requirement identifiers; this document carries the FR mapping instead.
4. **The service provider is a confidential client.** It authenticates to Login.gov with `private_key_jwt` (RFC 7523) on every call to the token, revocation and introspection endpoints. The service provider's own relationship with its users, where it may behave as a public client, is a client-side implementation and out of scope for this branch. Toward the agency APIs that rely on a delegated token it presents as a public client, which is why the branch adopts DPoP (RFC 9449): the relying party authenticates the presenter by the key the token was bound to (5.10). Any code or comment from `sbx-taigrr` that describes the service provider as a public client of Login.gov, or the exchange as something a browser calls, is corrected in the feature that touches it, or in 5.1 if nothing later touches it.
5. **Terminology.** *Service provider*, never "broker", for the application the user signs in to; *resource server* or *agency API* for the target; *agency SP* for the agency's record. Identifiers, strings, comments and analytics properties that say "broker" are renamed or removed by the feature that owns them.
6. **Names.** No real-world service provider or agency appears in code, fixtures, comments, strings or this plan. The fixtures use the fictitious names the design documents already use (MyBenefits Assistant, Office of Benefits Coordination, Department of Housing Support, National Retirement Administration); everywhere else the role name or the RFC term is used.
7. **No compatibility code.** Neither `sbx-taigrr` nor `token-exchange2` is in production. Nothing is kept, renamed to `legacy` or `old`, or left behind a flag because it might be depended on. Each feature decides what stays and what goes, and removes what goes.
8. **Local before CI.** Every feature runs locally first: its specs, and from 5.4 on the end-to-end harness against the local IdP and reference applications. Nothing is pushed to GitLab (which starts a pipeline and a review app on any branch) until that has happened.
9. The three documents in `docs/` (this plan, the functional requirements, the requirements document) are updated in the same change as the code or decision they describe, never later; they are the authoritative copies.

---

## 5. Features, in dependency order

Each feature lists: the functional requirements it serves; what `sbx-taigrr` has; what is added; what is removed and why; findings for engineering decisions; what to port from `token-exchange2-login` (commit shas on GitLab `lg/identity-idp`); its worktree; what it depends on. A feature never depends on a later one.

### 5.1 Onboarding data model and configuration

**Worktree** `lda-01-onboarding`. **Depends on** section 2 (main merged). **Decisions:** section 9, D1–D3, D7–D12.
**Requirements:** FR-ONB-1 to FR-ONB-9, FR-OPS-1; companion §3 (ONB-1..8 as amended in §3.4), §10.

**The model as decided.** An *application* is an agency's service provider record (one `service_providers` row the agency owns), extended with consent content and owning one or more *resource servers* (the application's API URLs). The person consents per application. The service provider requests one delegation scope per application, `token_exchange:<application scope value>`; the application's URLs are shown for information and `resource` selects one of them at exchange. Agency-level content (what the agency says about itself) lives on `agencies`.

**What `sbx-taigrr` has.** A service provider allow-list in `application.yml` (`token_exchange_service_providers`), a target opt-in column (`allowed_token_exchange_brokers`), two feature flags (`token_exchange_enabled`, `document_images_sharing_enabled`), and the two grant tables. Its targets are whole service providers, which is the application granularity decided on; what is missing is the URL registry under each application, the content, the versions, and the service provider approval on the SP record.

**Add.**
1. `agencies`: localized `delegation_description` (jsonb), `delegation_learn_more_url`, `consent_content_version`, `consent_material_version` (the version at which the last material change was made). FR-ONB-3, D9, D12.
2. `service_providers`, application role: `delegation_application` (boolean), `delegation_scope_value` (unique, `[a-z0-9_]{1,64}`, the part after `token_exchange:`), localized `delegation_display_name`, `delegation_description`, `delegation_data_provided`, `delegation_access_type` (`read`/`read_write`), `delegation_learn_more_url`, `consent_content_version`, `consent_material_version`, `consent_approved_at`/`consent_approved_by`, `allowed_delegation_service_providers` (string array; empty means any approved service provider). FR-ONB-2, FR-ONB-3, FR-ONB-5, FR-ONB-8, D1, D2, D7.
3. `service_providers`, service provider role: `token_exchange_enabled_sp`, operator legal name and type, localized service description, data-handling statement, AI description, `delegation_uses_ai`, privacy policy, terms and support contact, `sp_content_version`, `sp_material_version`. FR-ONB-1, FR-ONB-4, FR-ONB-6.
4. `token_exchange_resource_servers` as in `token-exchange2` (identifier URL, owning application, Attempts recipient SP, `billing_issuer`, `certs`, `token_format`, `dpop_required`, `active`): the application's URLs. FR-ONB-2, FR-ONB-7. No `token_exchange_scopes` table: with one scope per application the scope value and content live on the application row.
5. `token_exchange_grants`, new shape: `user_id`, `service_provider_issuer`, `application_service_provider_id`, `delegation_id`, `source` (`consent_screen`/`account_page`), `consented_at`, `remember_until` (null for a single-sign-in grant), `rails_session_id` (single-sign-in grants only), `agency_content_version`, `application_content_version`, `sp_content_version`, `proofed_in_session`, `first_exchanged_at`, `revoked_at`, `revocation_reason`; one live row per (user, service provider, application). D4, D6, D8, D9. The model carries the validity rule (live, not revoked, remembered-and-current or current-authorization, every recorded content version at or above the owner's material version).
6. Seeder and updater: nested `token_exchange_resource_servers` under an application upserted by `identifier`, children deactivated when absent from a Dashboard payload; the new SP and agency columns pass through. FR-ONB-7, FR-ONB-9.
7. `IdentityConfig` keys with defaults: token and refresh TTLs, introspection cache seconds, three rate-limit pairs, `delegation_outcomes_report_emails`. Companion §10.
8. `config/delegated_access.localdev.yml` and `rake delegated_access:seed` (refuses `prod` and `staging`): the fictitious service provider (MyBenefits Assistant, Office of Benefits Coordination), two agencies with one application each (Department of Housing Support; National Retirement Administration), one OAuth and one SAML resource server, content for all of them. Used locally, in the review app and in a personal sandbox until the Dashboard carries the fields. D10.
9. Explicit dependency notes, in code comments on the seeder, updater and models and in the requirements documents: the Dashboard (`identity-dashboard`) must gain the agency and application content fields, the service provider delegation fields, `allowed_delegation_service_providers` and nested resource servers in its API payload before partners can self-serve; `ServiceProviderUpdater` already reads that shape. D3, D10.
10. The migration that drops `sbx-taigrr`'s `token_exchange_grants`, `token_exchange_broker_settings` and `allowed_token_exchange_brokers`, and creates the above. Findings 1.
11. Full terminology sweep across the branch: every identifier, string, comment, analytics property and locale key that says "broker" says service provider; every comment describing the exchange as browser-callable or the service provider as a public client of Login.gov is corrected to the confidential-client baseline (section 4 item 4), including in code that later features will delete. D11.

**Remove, and why.**
1. `token_exchange_service_providers` from `application.yml`: approval to request delegation is partner configuration reviewed through the SP onboarding path (FR-ONB-9, ONB-5). Replaced by `service_providers.token_exchange_enabled_sp`. `token_exchange_enabled` stays as the master switch (FR-OPS-1). D7.
2. `token_exchange_broker_settings` and its model: auto-enrollment of future agencies conflicts with the registry-defined list the person chooses from (D4) and with FR-CEN-1. Pre-approval from the account page replaces the need.
3. `allowed_token_exchange_brokers`: replaced by `allowed_delegation_service_providers` on the application row with the same meaning and an "any approved service provider" default. D7.
4. The two localdev fixtures `urn:gov:gsa:openidconnect:sp:token_exchange_broker` and `…:token_exchange_target`: replaced by the seed file.

**Findings.**
1. *Grant tables.* The `agroot` sandbox database has `sbx-taigrr`'s `token_exchange_grants` and `token_exchange_broker_settings` with rows from earlier testing. Neither branch is in production, so nothing is kept for compatibility: one migration drops both tables and the opt-in column and creates the new ones. No renamed or retained copies; the sandbox data is disposable.
2. *Column comments.* Every new column needs `comment: 'sensitive=true|false'` (ONB-6); `sbx-taigrr` already does this.
3. *Localized content storage.* jsonb keyed by locale with an `en` fallback, rendered as escaped text, never as HTML (companion §3.2 note).
4. *Material versus editorial changes.* Two integers per content owner (`consent_content_version`, `consent_material_version`) let the Dashboard editor bump the first on every save and set the second equal to it only when the change is marked material. A grant is current when each recorded version is at or above the matching material version. D9.
5. *`agencies` is shared with every existing SP.* The new agency columns are nullable with defaults so nothing changes for agencies that never register an application.

**Port from `token-exchange2-login`:** `18079959bc` (data model, config keys, seeder and updater), re-shaped: no scopes table, content on the application and agency rows, grants keyed by (user, service provider, application), the drop-and-create migration. `592c9ad17f` is already on `login-delegated-access` as `c8d6f0cf1b`.

### 5.2 Authorize request and the consent screen

> **Kyle's notes (2026-10-09):**
> (note: consent will be at the application level and could include multiple URLs. We'll need a database to manage the content on the consent screen to manage the content for the agency as well as the app within the agency which may be different, as well as an easy means to update this content regularly)
>
> (note about this: 2. The grant control partial `_token_exchange_grant.html.erb`, its TypeScript pack `token-exchange-grant.ts`, and the "allow all linked", "auto-enroll", pagination strings: they implement consent for already-connected applications, which contradicts FR-CUX-3 (the request names the agencies) and FR-CUX-4. - this has changed. A user can go into their account and check off apps that they want to delegate access to which should be honored and reflected in the consent screen. this may change 3. `TokenExchangeReachableTargets`: reach is defined by the request and the registry, not by the user's connected applications, as well. the sbx-taigrr branch may be closer here)

Both notes are resolved by the 2026-10-09 interview (section 9, D1–D6, D9) and folded into the text below.

**Worktree** `lda-02-consent`. **Depends on** 5.1.
**Requirements (as amended 2026-10-09):** FR-CEN-1, FR-CEN-2, FR-CEN-3, FR-CEN-4, FR-CEN-5, FR-CEN-6, FR-CEN-7, FR-CEN-9, FR-CEN-10, FR-CEN-11, FR-CEN-12, FR-CEN-17; FR-CUX-1 to FR-CUX-11; companion §4.1–§4.6 (CON-1..19 as amended in §4.8).

**What `sbx-taigrr` has.** The service provider requests one scope, `token_exchange`; Login.gov cannot refuse an unknown target at authorize because no target is named (FR-CEN-1, FR-CEN-2 not met). The completions screen lists the applications the user has already connected that opted in to the service provider, grouped by agency, with "allow all linked", "auto-enroll new", or pick some. The disclosure is one generic sentence (FR-CUX-2 missing). The per-application checkboxes grouped by agency, the confirmation flow and the account-page link are close to the decided design; the population (connected applications only), the auto-enroll option and the sticky decline are not.

Confirmed by reading the code: `token_exchange` is in `requested_attributes`, and `update_verified_attributes` writes `verified_attributes: sp_session[:requested_attributes]`, so the completions-screen skip (`requested_attributes_verified?`) suppresses the screen for a year after any answer. Under the decided design there is no per-application decline to remember, but the mechanism still has to go because it also skips the screen for pre-approvals and content changes.

**Add.**
1. `token_exchange:<application scope value>` parsing in `OpenidConnectAuthorizeForm` and the SAML request handler; `invalid_scope` for an unknown, inactive or disabled application, a disabled agency, a service provider not approved for delegation, or an application whose `allowed_delegation_service_providers` excludes the caller (FR-CEN-1, FR-CEN-2). Identity-verified sign-ins only (FR-CEN-3). Requested applications stored in the SP session.
2. The consent screen: service provider card from the ONB-4 content; one row per requested application, labeled with the agency's public name and logo and the application's display name, with the application's description, data provided, read-only or can make changes, learn-more link, and its API URLs listed for information (FR-CUX-2, FR-CUX-3, FR-CUX-9, FR-CUX-10, FR-CUX-11). Requested applications are shown **selected and locked**: the only way to decline one is to cancel, which returns the person to the service provider with no sign-in (FR-CUX-4, FR-CUX-5, FR-CUX-6; D5). Applications the person pre-approved from the account page and not in the request are not shown; pre-approved applications that are in the request are selected and locked like the rest (FR-CUX-8).
3. "Remember my approvals for 12 months", unchecked by default, applying to the requested applications; unchecked means the grants are valid for this sign-in only (FR-CUX-7, FR-CEN-11; D6). Pre-approvals made on the account page are always remembered for up to 12 months from the moment of consent (D4).
4. `TokenExchangeConsent`: on submit, one grant per requested application with `source: consent_screen`, the three content versions, `remember_until` when asked, `rails_session_id` otherwise, `proofed_in_session` (FR-CEN-17). An existing live grant for the same (user, service provider, application), for example a pre-approval, is superseded by the new row so one live row remains.
5. When the screen is shown: whenever any requested application lacks a live grant that is remembered and current, or a material content change (agency, application or service provider) postdates the grant's recorded versions (FR-CEN-5; D9); never twice in one authorization (FR-CEN-7), identified by authorize URL (commit `a711ee5c20`).
6. `scope` in the token response listing only the approved `token_exchange:*` values, which after a completed screen is every requested value (FR-CEN-9).
7. Nothing is created at any agency (FR-CEN-10, FR-CEN-12): consent writes grant rows only.

**Remove, and why.**
1. `token_exchange` as an attribute scope in `OpenidConnectAttributeScoper` (`IAL2_SCOPES`, `ATTRIBUTE_SCOPES_MAP`, `CAPABILITY_SCOPES`): it names no application and its presence in `verified_attributes` skips the screen when it must be shown. Replaced by prefixed per-application scopes that never enter `verified_attributes`.
2. The "allow all linked" and "auto-enroll" controls and strings in `_token_exchange_grant.html.erb`: the request names the applications and they are not optional (D5); nothing is approved by default beyond that. The partial and its TypeScript pack are rewritten for the locked-row layout rather than kept.
3. `TokenExchangeReachableTargets.linked_for` (connected applications): the request defines what the screen shows (D5) and the registry defines what the account page offers (D4). A registry query replaces it in 5.3.
4. `record_token_exchange_decision`, `auto_enroll_token_exchange` and related methods in `VerifySpAttributesConcern`; replaced by the consent service.

**Findings.**
1. *Declines no longer exist as records.* FR-CEN-6, FR-CEN-17 and the outcomes report (5.8) lose the "declined" count; cancels are visible only as consent screens shown without a completed sign-in, which analytics already records.
2. *A locked checkbox must still be accessible.* The row is rendered as a required, checked, disabled control with the explanation that cancelling is how to decline; the approved mockup needs a revision for this (FR-CUX-11).
3. *Content approval fields* exist in the schema; there is no UI. FR-ONB-5 is met by the Dashboard process once the fields exist.

**Port:** `224903b8c5` (scope parsing, re-pointed at applications), the consent half of `268a4614ba`, `d85d69e163` (approved layout), `a711ee5c20` (authorize-URL identity), `0ff3f111d5` only if `invalid_target` text is needed at authorize. `ffb1b3da8b` is Attempts-side (5.7).

### 5.3 Account page: pre-approve, review and revoke

**Worktree** `lda-03-account`. **Depends on** 5.2.
**Requirements (as amended 2026-10-09):** FR-CUX-12, FR-CUX-13, FR-CUX-14, FR-CEN-14, FR-CEN-15; companion §4.7 (ACC-1..4 as amended in §4.8).

**What `sbx-taigrr` has.** Under the service provider's connected-app entry, a toggle per linked application and an auto-enroll toggle, each a form `PATCH` to `token_exchange_grants#update`, with a confirmation modal and a TypeScript pack. Shows "allowed since", not time remaining or token activity. The toggle-with-confirmation pattern is what the decided design needs; the list it toggles is the wrong one.

**Add.** Account → Delegated access (`accounts/delegated_access#show`): for each service provider approved for delegation that the person has connected to, every registered application that accepts that service provider, grouped by agency, each with a toggle. Turning one on, after the confirmation modal that shows the application's consent content, creates a remembered grant (`source: account_page`, 12 months from now). Turning one off revokes the grant, which cascades to its tokens (FR-CUX-12, FR-CUX-13; the cascade is FR-CEN-13 and lands fully in 5.5). Each row shows approval time, time remaining, whether a token is active now, and the application's APIs and access type. Revoke-all per service provider. Link from the connected services list (FR-CUX-14). `RevokeServiceProviderConsent` revokes that service provider's grants (FR-CEN-14). Grants survive sign-out (FR-CEN-15).

**Remove, and why.** The auto-enroll toggle and `TokenExchangeBrokerSetting` (gone in 5.1); `TokenExchangeReachableTargets.linked_for` and the connected-applications population; `_token_exchange_manage.html.erb`, `token-exchange-manage.ts`, `TokenExchangeGrantsController` and `TokenExchangeBrokerPresenter` are rewritten under the new names for the registry-wide list rather than kept, because every identifier and string in them carries the old vocabulary and the old population.

**Findings.**
1. *Service providers the person has not connected to.* The page lists applications under service providers the person has connected to at least once; pre-approving for a service provider the person has never used has no identity to hang analytics or notifications on and is deferred (functional requirements section 4, question 13 is adjacent).
2. *Long lists.* Every registered application for a popular service provider could be dozens of rows; group by agency and paginate client-side as `sbx-taigrr` does.

**Port:** the account half of `268a4614ba` (page, revoke cascade), `b2dd2d7a2d` (rows tagged with their scope value); the toggle and modal pattern from `sbx-taigrr` under new names.

### 5.4 Server-to-server token exchange

**Worktree** `lda-04-exchange`. **Depends on** 5.1, 5.2 (grants to check).
**Requirements:** FR-TOK-1, FR-TOK-2, FR-TOK-3, FR-TOK-4, FR-TOK-5, FR-TOK-6, FR-TOK-7, FR-TOK-8, FR-TOK-17, FR-TOK-19, FR-TOK-20 (exchange half), FR-TOK-21, FR-CEN-8, FR-CEN-10, FR-CEN-12, FR-CEN-16; companion §5 (EXC-1..12), §6.2 (authenticator).

**What `sbx-taigrr` has.** `POST /api/openid_connect/exchange`, no CSRF, no client authentication, a CORS rule for browsers (FR-TOK-2 violated). The subject token is the service provider's own access token looked up in `identities`; the exchange requires its Rails session to be live (FR-TOK-7 met) and mints by `IdentityLinker#link_identity` against the target SP with `last_consented_at: now` (FR-CEN-12 violated: the target appears in connected services as if the user signed in there, and a later direct sign-in skips its consent screen). The minted token is a normal target access token that works at userinfo, so the service provider can read the target's attributes (FR-TOK-6 violated), and an `id_token` for the target is returned to the service provider. Lifetime is the service provider session's (FR-TOK-4 partial). Target revoked or in use by another live session is refused (FR-TOK-8 met). No rate limiting (FR-TOK-20). Scope narrowing in claim space is careful but narrows attributes the service provider should never receive at all.

**Add.**
1. `ResourceServerAuthenticator`: RFC 7523 `private_key_jwt` verification parameterized by key source. As far as this branch is concerned the service provider is a confidential client: it holds a private key and authenticates to Login.gov with it on every call. Verification is parameterized by key source (service provider certificates, or resource server certificates), RS256 pinned, `aud` must be the endpoint, five-minute lifetime, `jti` replay cache in Redis (FR-TOK-2, FR-TOK-19). Used by exchange, refresh, revocation and introspection.
2. `OpenidConnectTokenExchangeForm` (new body under the existing class name): dispatched from the existing token endpoint on `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` (FR-TOK-1); subject token is the service provider's access token and its sign-in must be live (FR-TOK-7); `resource` names exactly one registered API (RFC 8707, FR-TOK-3); the grant for that API must be live and current (FR-CEN-8); disabled scope, resource server, agency or service provider refuses (FR-CEN-16); IAL and AAL forwarded; the agency's allowed-service-provider list re-checked.
3. `TokenExchangeToken`: opaque, SHA-256 digest stored, `aud`, `scope`, `delegation_id`, forwarded `ial`/`aal`, `refresh_family_id`, 15-minute expiry (FR-TOK-4, FR-TOK-5, FR-TOK-21). Not an `identities` row, so userinfo refuses it and nothing is created at the agency (FR-TOK-6, FR-CEN-10, FR-CEN-12, FR-TOK-8).
4. Response: `access_token`, `issued_token_type`, `token_type`, `expires_in`, `scope`, `refresh_token` (the refresh table arrives in 5.5; until then the response omits `refresh_token` and the family id is still recorded so 5.5 can attach to it). No `id_token`.
5. Rate limit per service provider on exchange (FR-TOK-20).
6. Error mapping per RFC 8693 §2.2.2 (`invalid_request`, `invalid_target`, `invalid_grant`, `consent_required`), target-side errors withheld until the caller is authenticated.

**Remove, and why.**
1. `OpenidConnect::ExchangeController`, the `/api/openid_connect/exchange` routes and the CORS rule: the exchange is server-to-server at the token endpoint; a browser-reachable endpoint is the attack FR-TOK-2 exists to prevent.
2. Minting through `IdentityLinker` against the target and the `id_token` with `act` for the target: a delegated token must not be a sign-in credential at the agency, must not read attributes, and must not create a connection (FR-TOK-6, FR-CEN-12). The `act` fact moves to introspection and the SAML assertion (5.6, 5.9).
3. `IdTokenBuilder`'s `actor:` parameter and the `c_hash`/`nonce` omission: no `id_token` is issued for a delegation. Revert to `main`'s builder.
4. The `target_in_use` check: there is no target identity to hijack. The `target_revoked` idea survives as "a revoked service provider connection ends its grants" (5.3).
5. The claim-space narrowing (`BUNDLE_ATTRIBUTE_TO_CLAIM`, `target_scope`, `target_allowed_claims`): attributes are released only to the agency at introspection, bounded by the agency's own `attribute_bundle` (5.6).

**Findings.**
1. *Same class name, new body.* Keeping the name `OpenidConnectTokenExchangeForm` matches the convention of the other token-endpoint forms (`OpenidConnectTokenForm`, `OpenidConnectRefreshTokenForm`). The `sbx-taigrr` spec file is replaced, not merged.
2. *`token_form.rb` dispatch.* `TokenController#build_form` grows a `case grant_type` with the exchange, refresh and unsupported-grant forms. This is the file that conflicts with current `main` on `token-exchange2-login`, so port it from scratch against the merged code.
3. *Sign-in must be live for first issuance* (FR-TOK-7, functional requirements section 6, question 5) is preserved from both branches.
4. *Null-byte guard* (`db_safe?`) from `sbx-taigrr` is a good habit worth keeping on every lookup by untrusted value.

**Port:** `9fecebecfd` (authenticator and helper), `7cca3700b9` (exchange form and the billing row; the billing row waits for 5.8, so the port lands the row-writer call behind a method that 5.8 fills in), `0ff3f111d5` (`invalid_target` when not delegated), the token model and `DelegatedTokenClaims` from `dffd060fcb`'s neighbors as needed.

### 5.5 Token lifecycle: refresh, revocation, suspension and deletion

**Worktree** `lda-05-lifecycle`. **Depends on** 5.4.
**Requirements:** FR-TOK-10, FR-TOK-11, FR-TOK-12, FR-TOK-13, FR-TOK-14, FR-TOK-15, FR-TOK-16, FR-TOK-18, FR-TOK-20 (refresh half), FR-CEN-13, FR-CEN-15 (suspension and deletion); companion §7 (REF-1..9), §11.

**What `sbx-taigrr` has.** Nothing: the minted token dies with the service provider's browser session (FR-TOK-15 violated), there is no renewal, no revocation endpoint, and revoking a grant does not stop an already-minted token (FR-TOK-10 to FR-TOK-16, FR-CEN-13 missing).

**Add.**
1. `TokenExchangeRefreshToken`: rotating, digest-only storage (FR-TOK-18), one family per exchange with an absolute 12-hour end never past `remember_until` (FR-TOK-10, FR-TOK-11), reuse of a rotated token revokes the family and is reported (FR-TOK-12; the report is 5.7), everything copied from the family so nothing can widen at renewal (FR-TOK-13).
2. `OpenidConnectRefreshTokenForm` at the token endpoint for delegated families (`grant_type=refresh_token`, client assertion required), rate-limited per service provider (FR-TOK-20).
3. RFC 7009 revocation endpoint `POST /api/openid_connect/revoke` (FR-TOK-14), authenticated the same way.
4. Grant revocation cascades to access and refresh tokens (FR-CEN-13); account suspension and deletion revoke everything (FR-CEN-15); shorter family lifetime per service provider or per read-write API (FR-TOK-16) as configuration on the resource server and service provider.
5. Lifetime independent of the user's browser session (FR-TOK-15): already true of the token model in 5.4; the refresh family is what makes it useful.

**Remove, and why.** Nothing from `sbx-taigrr` remains in this area after 5.4.

**Findings.**
1. *Family absolute lifetime versus functional requirements section 6, question 2.* The 12-hour default is a configuration key; per-API shortening needs a column (`max_family_seconds` on the resource server) that `token-exchange2` does not have. Small addition.
2. *Revocation by assertion id for SAML* arrives with 5.9.

**Port:** `663bcc2dbd` (refresh and revocation), the suspension and deletion half of `60b53f3ef8`.

### 5.6 Agency verification (introspection)

**Worktree** `lda-06-introspection`. **Depends on** 5.4, 5.5 (revoked state), 5.1 (resource server certificates).
**Requirements:** FR-VER-1 to FR-VER-8, FR-TOK-5, FR-TOK-6; companion §6 (INT-1..11), NIST IR 8587 §5.2.1.1 element list.

**What `sbx-taigrr` has.** The agency would call userinfo with the minted token (FR-VER-1 partial). Userinfo is bearer-only, so the service provider holding the same token learns the same attributes (FR-VER-2 violated). No acting party, approved access or delegation identifier in the response (FR-VER-3 partial); no cache guidance, no rate limit (FR-VER-7, FR-VER-8).

**Add.**
1. `POST /api/openid_connect/introspect` (RFC 7662) authenticated by the resource server's `private_key_jwt`; answers only for the token's own audience; any other caller, including the service provider, gets `active: false` with no reason (FR-VER-1, FR-VER-2, FR-VER-6).
2. Active response: `iss`, `sub` (the agency's pairwise identifier), `aud`, `scope`, `act`, `delegation_id`, `ial`/`aal`, `auth_time`, `iat`, `exp`, `jti`, `token_type`, `cnf` when bound (FR-VER-3, FR-TOK-5), plus the identity attributes the agency's `attribute_bundle` allows in userinfo shape (`OpenidConnectClaimsFormatter`), while the service provider's sign-in is live; identifiers and email only afterwards, stated as such (FR-VER-4, FR-VER-5).
3. Published cache window (60 seconds) and a per-resource-server rate limit (FR-VER-7, FR-VER-8).
4. `AccessTokenVerifier` refuses delegated tokens at userinfo (reinforces FR-TOK-6).

**Remove, and why.** Nothing remains from `sbx-taigrr` in this area after 5.4.

**Findings.**
1. *Endpoint choice* (functional requirements Appendix A item 7) is answered by this feature as introspection; the alternative (extend userinfo with agency authentication) was judged in the requirements doc as more invasive to the existing endpoint. The agency reference application already implements introspection.
2. *Email released* is the one shared with the service provider (section 7, question 3) until decided otherwise.

**Port:** `f2546865a0`, `4477c8941c`, `7bdc343846`, `b92213d169`, `afae4eafbf`, `0505475dca`, `5693e91e63`.

### 5.7 Fraud signals: Attempts API delivery to agencies

**Worktree** `lda-07-fraud-signals`. **Depends on** 5.2 (consent is the release point), 5.4, 5.5 (token events).
**Requirements:** FR-FRD-1 to FR-FRD-9, FR-CEN-13 (reported to the agency), FR-TOK-12 (reuse reported); companion §8 (ATT-1..10).

**What `sbx-taigrr` has.** One `token-exchange-login-completed` event to the target at mint carrying `broker_issuer`, encrypted to the target's key, with the IdP session id replaced by an opaque hash and the service provider's network details deliberately omitted (a sound choice: FR-FRD question 5). Nothing else: no sign-in, MFA or device history from the service provider session, no identity-verification history, no consent event, no later events, no revocation event, no delegation identifier (FR-FRD-1, 2, 4, 6, 7 missing).

**Add.**
1. Buffering of the sign-in session's events while a delegation request is in flight, encrypted at rest and discarded at session end (FR-FRD-1, FR-FRD-9): `DelegationContext`, `DelegatedEventWriter`.
2. Release at consent to each approved agency, attributed to the agency's pairwise identifier, with a `delegation-consented` event and the identity-verification history once per agency (`HistoricalReleaseCheck`); nothing to declined agencies (FR-FRD-2, FR-FRD-3): `DelegatedRelease`.
3. Later session events forwarded to approved agencies while the sign-in is live (FR-FRD-4).
4. `delegated-token-issued`, `delegated-token-refreshed`, `delegated-access-revoked` (with reason, including refresh-token reuse) events (FR-FRD-5, FR-TOK-12, FR-CEN-13), every delegated event carrying `delegation_id` and the acting service provider (FR-FRD-6).
5. Remembered consent reuse delivers the sign-in events and a consent event marked remembered (FR-FRD-7).
6. Agencies without a usable encryption key are treated as not enrolled; delivery is best-effort and never blocks the user (`875576cb4d`, `e8ffc696d7`). Existing integrations unchanged (FR-FRD-8). Event schemas documented under `docs/attempts-api/schemas`.

**Remove, and why.** `token_exchange_login_completed` tracker event and its schema file: it reports a sign-in at the target, which under the new design never happens; the token-issued event with `delegation_id` replaces it. The opaque-session-id and no-network-details decisions are kept in the new events.

**Findings.**
1. *Privacy review* (functional requirements section 8, question 1) is a precondition for enabling delivery in any shared environment; the code ships behind the master switch.
2. *Agency not enrolled in Attempts* receives nothing (question 3); the outcomes report (5.8) shows which APIs' recipients are enrolled.

**Port:** `42bc27b38b`, `7e4c20dab8`, `e944cb14a9`, `875576cb4d`, `e8ffc696d7`, `ffb1b3da8b`.

### 5.8 Billing and reporting

**Worktree** `lda-08-billing`. **Depends on** 5.4 (exchange writes the row), 5.5 (renewals write nothing), 5.2 (declines for the outcomes report), 5.1 (`billing_issuer`).
**Requirements:** FR-BIL-1 to FR-BIL-10; companion §9 (BIL-1..14) and *How billing works under delegated access*; reviewer note `docs/delegated-access-billing-strategy.md` on `token-exchange2-login`.

**What `sbx-taigrr` has.** An `SpReturnLog` row for the target at mint with the same IAL and profile attribution as a direct sign-in (FR-BIL-1 partial: not marked delegated, no actor), billable once per (user, target, service provider session) through a deterministic `request_id` (FR-BIL-2 in spirit, but keyed to the browser session rather than the approval), the existing monthly grouping (FR-BIL-3), no breakdown (FR-BIL-4), no outcomes report (FR-BIL-5), the service provider never billed for the target's return (consistent with FR-BIL-8 only in the "exchanged" case).

**Add.**
1. `Billing::SpReturnLogWriter` shared by the direct handoff and the exchange, so the two row shapes cannot drift (BIL-6).
2. Delegated row at exchange under the resource server's `billing_issuer`, IAL from the sign-in, profile attribution unchanged, request id `tx:<delegation_id>:<billing issuer>:<ial>` so the first exchange per approval is billable and later ones are trail rows; renewals write nothing (FR-BIL-1, FR-BIL-2, FR-BIL-6, FR-BIL-7).
3. Report changes: delegated rows counted under the agency; per-user grouping fixed so a person is never counted twice or treated as new (FR-BIL-3, FR-BIL-9); delegated-only breakouts on the agreement report, partner report and invoice supplement (FR-BIL-4, FR-BIL-9).
4. `DelegationOutcomesReport` (monthly): requested, declined, approved-never-exchanged, exchanged, proofed-in-session-not-exchanged, per service provider, agency and API; billing issuer has agreement; the sign-ins table (FR-BIL-5, FR-BIL-8, FR-BIL-10). Seeder and updater warnings for an API whose billing issuer has no agreement (FR-BIL-10).
5. The service-provider sign-in waiver (FR-BIL-8), redesigned per the reviewer's note: no mutation of `sp_return_logs`; a cache entry written at the service provider's handoff keyed by the digest of its access token (the subject token), resolved at exchange; an append-only `sp_return_log_billing_adjustments` row (`exclude_from_billing` / `delegated_token_issued`, integer enums) pointing at the sign-in row, the delegated row and the token; invoice queries exclude adjusted rows with `NOT EXISTS`; explicit cache-miss behavior (exchange proceeds, no adjustment, logged and alerted).

**Remove, and why.**
1. `sbx-taigrr`'s `bill_target` and `billing_request_id` in the exchange form: the dedupe key becomes the approval, not the browser session, and the row carries the agency's billing issuer rather than the target SP issuer.
2. Not ported from `token-exchange2`: `sp_return_logs.identity_id`, the `delegating_sign_in` access type, and `waive_sign_in_billing`; the reviewer's objection (a return log is append-only; identity is user plus issuer, not one sign-in) is correct and the cache plus adjustment design meets FR-BIL-8 without them.

**Findings and decisions.**
1. *Marker columns on `sp_return_logs`.* FR-BIL-1 says the record is "marked as delegated and naming the acting service provider and API"; the reviewer recommends keeping return logs to existing fields and putting the evidence on the adjustment or the token record. Recommendation: keep one column, `access_type` (`direct`/`delegated`), because the direct/delegated breakdowns of FR-BIL-4 and FR-BIL-9 need it in every report query; move `actor_issuer`, `resource_server_identifier` and `delegated_proofing` off the return log onto `token_exchange_tokens` (which already has service provider, resource server and grant) and have the outcomes report join there. FR-BIL-1's wording would then be satisfied by the join, and the requirements doc gets a note. This needs the product owner's agreement because it changes BIL-13's mechanics.
2. *Cache window.* The waiver depends on the exchange happening while the cache entry lives. The exchange already requires the sign-in session to be live (FR-TOK-7), so a TTL equal to the session's absolute lifetime (12 hours) loses nothing and keeps the two rules aligned. The reviewer asks for this to be product-approved.
3. *Cache miss over-bills the service provider*, never an agency. Acceptable for a first implementation; the alert makes it visible.
4. *Proofing cost attribution* (functional requirements section 9, question 1) remains unresolved; `proofed_in_session` stays on the grant so the outcomes report can show it.
5. The reviewer's two-branch plan (cache link, then adjustments) fits inside this one worktree as two commits.

**Port:** `7cca3700b9` (writer and the delegated row), `9dd8969993` (reports), `e634d7f47c` (outcomes report), the report-key fix and breakouts from `52fa7526ff` without its waiver mechanics; new code for the cache link and adjustments. The documents `e0fc8df5d1`, `73a92c73a8`, `40d226de5c`, `bd32c5f4e2` are not ported (no prose documents on the branch; the reviewer's note stays on `token-exchange2-login` for the record and is reflected in this section).

### 5.9 SAML assertions as an issued token type

**Worktree** `lda-09-saml`. **Depends on** 5.4, 5.5, 5.6 (claims and attribute bounding), 5.1 (`token_format`).
**Requirements:** FR-TOK-9, FR-VER-9; companion §15 (SAML-1..9).

**What `sbx-taigrr` has.** Nothing.

**Add.** `requested_token_type=urn:ietf:params:oauth:token-type:saml2` at exchange and refresh for resource servers with `token_format: saml2`; `DelegatedSamlAssertion` built on the `saml_idp` builder extended to omit `InResponseTo` and take a subject-confirmation window (`lib/saml_idp_extensions/assertion_builder.rb`); attributes `delegation_scopes`, `delegation_id`, `actor`, and the agency's bundle; encrypted to the agency's certificate when registered; `TokenExchangeToken` row keyed by the assertion id's digest; revocation by assertion id; the family remembers the token type (FR-TOK-9, FR-VER-9).

**Findings.** Revocation of an already-issued assertion is observed by the agency only at expiry (functional requirements section 7, question 5), which the five-minute window bounds.

**Port:** `57633dc88c`, `dffd060fcb`, `cbe9e6ae64`, `cb910e9a71`, `f8d062a20c`, `fd04c44c5c`.

### 5.10 Sender-constrained tokens (DPoP)

**Worktree** `lda-10-dpop`. **Depends on** 5.4, 5.5, 5.6, 5.9 (SAML attribute), 5.1 (`dpop_required`).
**Requirements:** FR-TOK-22, FR-TOK-23; companion Appendix C and Appendix E rows E28–E32; *How DPoP works in the OIDC implementation*.

**What `sbx-taigrr` has.** Nothing.

**Why this branch adopts it.** Toward Login.gov the service provider is a confidential client (5.4). Toward the agency APIs that rely on the delegated token it presents as a public client, so the branch adopts DPoP (RFC 9449) to let a relying party authenticate the presenter: the token is bound to a key the service provider holds, and every use must carry a proof signed by that key (FR-TOK-22, FR-TOK-23). How the service provider manages that key on its own side is a client implementation and out of scope here.

**Add.** `DpopProofVerifier` (parse, `typ`, `alg` ES256/RS256, public-only `jwk`, signature, `htm`, normalized `htu`, `iat` window, `ath`, expected thumbprint, `jti` replay in Redis); `DPoP` header read at the token endpoint; `dpop_jkt` on the token and copied through the family; `dpop_required` per resource server refuses an exchange without a proof; refresh of a bound family requires the same key; introspection returns `token_type: DPoP` and `cnf.jkt`; SAML `dpop_jkt` attribute; `dpop_signing_alg_values_supported` in discovery; `invalid_dpop_proof` error (FR-TOK-22, FR-TOK-23). No server nonce (E28; functional requirements section 6, question 4 remains open).

**Port:** `a3d079c349`.

### 5.11 Operations: discovery, monitoring, rollout fixtures

**Worktree** `lda-11-operations`. **Depends on** everything above it uses; can start after 5.6 and finish last.
**Requirements:** FR-OPS-1, FR-OPS-2, FR-OPS-4, FR-OPS-5 (IdP side: fixtures that the reference applications and harness expect); companion §5.4 (DISC-1..5), §12, §13.

**What `sbx-taigrr` has.** `token_exchange_enabled` master switch (FR-OPS-1), not advertised in discovery; analytics events for exchange and consent decisions (FR-OPS-2 partial); no reference applications or harness (FR-OPS-4, FR-OPS-5 missing); a design document rather than a partner guide (FR-OPS-6; documents live on Drive, not on the branch).

**Add.** Discovery metadata advertised only when the switch is on (`grant_types_supported`, `introspection_endpoint`, `revocation_endpoint`, `token_endpoint_auth_methods_supported`, `dpop_signing_alg_values_supported`); the analytics event sweep so every endpoint and decision logs volumes and errors with consistent property names; the end-to-end review of `docs/attempts-api/schemas`; localdev fixtures aligned with the three reference applications so the harness runs against this branch; the test sweep against the threat table (companion §11, §12).

**Remove, and why.** `sbx-taigrr`'s `openid_connect_token_exchange` analytics properties (`broker_issuer`, `target_issuer`, `minted_ial`, `minted_scope`) are replaced by the new form's properties under the same event name, since the old shape describes a response that no longer exists. `docs/token-exchange.md` is removed from the branch (the design it describes is superseded; prose documents live on Drive).

**Port:** the discovery half of `60b53f3ef8`; the analytics docstrings across the ported commits.

### 5.12 Document images, document metadata and the passport-agency channel

**Worktree** `lda-12-biometric`. **Depends on** 5.6 (introspection is the release channel), 5.9 (if the passport agency chooses SAML). **No implementation proposed until the decisions below are taken; the worktree exists so the decision has a place to land.**
**Requirements:** FR-DOS-1 to FR-DOS-19, FR-TOK-6, FR-VER-4, FR-VER-5; companion §6 attribute release, §15; *Risk Based Decision* docx §3.3.

**What `sbx-taigrr` has.** A complete channel for a service provider the user signs in to directly: `document_images` scope, per-SP allow-list (`document_images_sharing_service_providers`), purpose-specific biometric consent checkbox on the completions screen (re-asked after re-proofing, FR-DOS-6 in spirit), encrypted artifact and metadata rows linked to the profile through the capture session with row locking against the worker race, bearer-authenticated download endpoint, 90-day expiry job, audited releases that never log the image (FR-DOS-9, FR-DOS-17), mDL exemption, two design documents including an SP 800-63-4 analysis that itself concludes "do not enable in production before [the remediations]".

Against the passport use case (FR-DOS) it differs in four ways: images go to the SP the user signed in to, not to an agency through delegation (FR-DOS-1, FR-DOS-2, FR-DOS-10); it ships the ID document front, back or passport image and the document number and dates as well as the selfie (functional requirements section 11, question 6 asks whether the agency needs more than the selfie); Login.gov decrypts and serves the image over TLS rather than encrypting it to the agency's key and signing it (FR-DOS-12); declining blocks the user instead of withholding the image (FR-DOS-7). Through the STS as built in 5.4–5.6, a delegated token never sets `biometric_sharing_consent_at` on any identity, so the artifacts are unreachable by delegation, which is the safe default.

**Keep.** All of it, as a feature for direct service providers, behind its own flag, which is off. It does not conflict with any STS requirement and removing it would discard tested work the passport-agency conversation may want.

**Decisions before any work.**
1. Selfie from Login.gov or the agency's own capture (functional requirements Appendix A item 11; FR-DOS-19).
2. If from Login.gov: verification response with an encrypted, signed selfie field, or a SAML assertion (Appendix A item 14). The former reuses 5.6 and adds a per-agency encryption key on the resource server; the latter reuses 5.9's encryption.
3. Whether the `document_images` direct-SP feature stays enabled anywhere while the STS channel is built, given the SP 800-63-4 analysis on the branch.
4. Whether to persist a new store of artifacts for release at all (FR-DOS-15 says no; `sbx-taigrr`'s `document_artifacts` table is exactly such a store, justified there by the escrow that already exists).

**Port:** nothing from `token-exchange2-login`; it has no biometric channel.

### 5.13 Third-party-initiated login

No identity-idp work. The pattern is implemented in the three reference applications (`identity-sts-sinatra`, `identity-oidc-sinatra`, `identity-saml-sinatra`) and runs against an unchanged identity provider (FR-TPL-1 to FR-TPL-10; companion §16). It is listed here only so the sequence is complete: it can be exercised in the sandbox as soon as the agency reference applications are registered as ordinary service providers there (section 7.6).

---

## 6. Cross-cutting considerations

1. **Order of operations is forced by the schema.** 5.1 is the only step everything waits on. 5.2 and 5.3 (consent and account) are independent of 5.4 (exchange) once the grants table exists; 5.5, 5.6, 5.7, 5.8 all need 5.4; 5.9 and 5.10 need 5.6. This is the same chain as companion Appendix D.3, with the `sbx-taigrr` removals attached to the feature whose premise they contradict.
2. **Migrations replace; nothing is kept for compatibility.** The sandbox database has `sbx-taigrr`'s schema, so every structural change is a new migration file that drops what changes shape and creates what replaces it. No table, column, class or method is kept under a `legacy`, `old` or similar name because it might be in production: neither branch is. `allow_unsafe_migrations` is already true for the `agroot` environment.
3. **Two things named the same.** Section 3.3 lists the collisions. Each is resolved inside the feature that owns the new meaning; no shim keeps both meanings alive, because a dual meaning in `token_exchange_grants` or `OpenidConnectTokenExchangeForm` would be worse than a clean replacement.
4. **The reviewer's billing note changes an accepted design.** BIL-13 in the requirements document and *How billing works under delegated access* describe the mutation-based waiver. Once 5.8's decision 1 is taken, both documents and FR-BIL-8's "together with the first agency charge" need a one-paragraph update describing the adjustment row instead.
5. **Specs.** `sbx-taigrr` adds 206 examples, `token-exchange2` 326. Specs for removed `sbx-taigrr` behavior are deleted with the behavior; ported specs come with their code. The live harness in `identity-sts-sinatra` is the acceptance test for 5.4 onward and needs the fixtures from 5.1 and 5.11.
6. **Locales.** Every user-facing string in four languages, single-quoted when it contains a colon. `sbx-taigrr`'s strings for removed controls are deleted in the same commit as the control.
7. **Analytics documentation.** `make analytics_events` runs in the deploy build (`deploy/build-post-config`); every analytics method needs a docstring or the build fails.
8. **Documents on the branch.** Three documents live in `docs/` and are the authoritative source, updated in the same unit of work as the code (decided 2026-10-09; earlier the rule was no prose on the branch): this plan (`docs/delegated-access-implementation-plan.md`), the functional requirements (`docs/delegated-access-functional-requirements.md`) and the requirements document (`docs/delegated-access-requirements.md`). Other inherited prose is handled by the feature that owns it: `docs/token-exchange.md` (from `sbx-taigrr`) is removed in 5.1 with the terminology sweep because it describes the superseded design; the two `docs/proofing/*.md` documents stay until the 5.12 decision; the reviewer's `docs/delegated-access-billing-strategy.md` on `token-exchange2-login` is not ported, its substance being in 5.8. Attempts API schema files under `docs/attempts-api/schemas` are machine-read and stay.
9. **Commit messages** describe behavior and the reason, cite RFCs, carry no requirement identifiers and no attribution trailers.
10. **The Dashboard knows none of this.** Neither branch's service provider fields (`allowed_token_exchange_brokers`, `token_exchange_enabled_sp`, nested resource servers) exist in `identity-dashboard` (`main` at `7d61d938`, 2026-10-07). Until it does, sandbox records are seeded another way (7.4). A Dashboard change is a separate piece of work that should follow 5.1.

---

## 7. Infrastructure: how `sbx-taigrr` runs in the sandbox, and what to do differently

### 7.1 How `sbx-taigrr` is deployed today

1. **Environment.** `agroot`, Tai Groot's personal sandbox, defined in `identity-devops` at `kitchen/environments/agroot.json` (created 2026-07-06). It sets `deploy_branch.identity-idp: sbx-taigrr` and `allow_unsafe_migrations: true`. Everything else is the template.
2. **Branch resolution.** The `login_dot_gov::idp_base` recipe resolves the branch with `git ls-remote https://github.com/18F/identity-idp.git <branch>`, then fetches the prebuilt artifact `s3://<artifacts bucket>/agroot/<sha>.idp.tar.gz` or clones at that revision. The branch must exist on **GitHub**. This is why `sbx-taigrr` is on GitHub and why `token-exchange2-login`, which is only on GitLab, cannot be deployed this way today.
3. **Application configuration.** `deploy/activate` and `identity-hostdata` deep-merge the environment's `application.yml` from the app-secrets S3 bucket (`/agroot/idp/v1/application.yml`) over `config/application.yml.default`. It is edited with `bin/app-s3-secret --env agroot --app idp --edit` in `identity-devops`. Tai's values for `token_exchange_enabled`, `token_exchange_service_providers`, `document_images_sharing_enabled`, `document_images_sharing_service_providers`, `doc_escrow_enabled` and `doc_escrow_s3_storage_enabled` live there; I cannot read them from here (no AWS access), so the exact sandbox settings are unverified.
4. **Service providers and agencies.** `deploy/activate` clones `18F/identity-idp-config` (`main`, from GitHub) and symlinks `service_providers.yml`, `agencies.yml`, the IAA and partner files and `certs/sp` into the app; `ServiceProviderSeeder` applies them at `db:seed`. In lower environments `ServiceProviderUpdater` also pulls from that environment's Dashboard (`use_dashboard_service_providers`). `identity-idp-config` is shared by every environment and is private (not reachable from this account). Because the seeder passes every YAML key straight to `update!`, a key unknown to `main`'s `ServiceProvider` model (such as `allowed_token_exchange_brokers`) would raise in every other environment's seed, so it cannot have been added there. Tai most likely set the target opt-in directly in the sandbox database or through a console.
5. **Workers, Redis, S3.** Standard for a sandbox: GoodJob workers on the worker hosts (the `expire_document_artifacts` cron is registered in `job_configurations.rb`), Redis for sessions and throttles, the encrypted document storage bucket for escrow.
6. **No reference applications.** The branch's localdev fixtures describe a service provider on `localhost:8788` and a target on `localhost:8787` as a "local proof of concept". Nothing on the branch runs a service provider or target in the sandbox; exchange was presumably exercised with Dashboard-registered SPs and direct HTTP calls.

### 7.2 How `token-exchange2-login` runs today

Only locally: IdP on `localhost:3000` with `config/service_providers.localdev.yml` and `config/agencies.localdev.yml`, resource server certificates generated per developer and copied into `certs/sp/` (ignored), `rake dev:prime` for the identity-verified user, a local `application.yml` enabling the Attempts API with scrypt-hashed poll tokens, and the three Sinatra applications on ports 9292, 9393 and 4567 with the harness in `identity-sts-sinatra/spec/e2e`. None of that transfers to a sandbox as is.

### 7.3 Two routes to a sandbox

**Route A: a Chef-managed personal environment (the `agroot` model).** Full fidelity: EC2 hosts, workers, Redis, S3, the Attempts API's S3 storage, scheduled reports, real `identity-idp-config` and Dashboard. Requirements: the branch on GitHub `18F/identity-idp` (someone with write access pushes `login-delegated-access`, or GitHub is the place the branch is created and GitLab mirrors it; the account used here has read-only GitHub access), an environment JSON in `identity-devops` pinning `deploy_branch.identity-idp: login-delegated-access` (either a new `kneuman` environment from the template, or a one-line change to `agroot.json`), an `application.yml` in the app-secrets bucket, and a recycle or deploy.

**Route B: a GitLab review app.** Any non-`main` branch pipeline on `lg/identity-idp` runs `build-idp-image` and the `review-app` job, which applies an ArgoCD `Application` from `identity-eks-control` (`cluster-reviewapp/envs/reviewapps`) and brings up `https://<slug>.reviewapps.identitysandbox.gov` with its own PostgreSQL, Redis, PIV/CAC and a Dashboard at `<slug>-portal`, stopping after two days. Configuration is `cluster-reviewapp/envs/reviewapps/idp/config/application.yml` in `identity-eks-control` (shared by all review apps; `LOGIN_SKIP_REMOTE_CONFIG=true`, `use_dashboard_service_providers: true`, `doc_auth_vendor: mock`, `ruby_workers_idv_enabled: false`, email disabled); `service_providers.yml` is an empty ConfigMap, so service providers come from the review-app Dashboard or a console. A Rails console is available with `kubectl exec` as the job output documents. Good for consent, exchange, refresh, revocation, introspection and DPoP, and for showing the team without infrastructure work. Not good for the Attempts API's S3 path, scheduled reports, document escrow, or anything that needs a worker.

Recommendation: use Route B for every feature's first sandbox run, because it needs no access the GitLab branch does not already have. Use Route A for 5.7 (fraud signals), 5.8 (billing reports) and the full harness, and start the access requests for it now: a GitHub push of the branch and an `identity-devops` environment change are the two gates.

### 7.4 What to do differently so the branch runs in a sandbox

1. **Keep `main` close.** Section 2's merge, repeated whenever `main` moves materially, so a sandbox deploy of the branch is a deploy of current Login.gov plus the feature.
2. **Every new config key has a safe default in `application.yml.default`** (all of `token-exchange2`'s do) so the branch boots in any environment with no `application.yml` change, and the feature is off until the environment's file turns it on. For the sandbox, the `application.yml` change is one block: `token_exchange_enabled: true`, the TTLs and rate limits, `delegation_outcomes_report_emails`, `attempts_api_enabled: true` with the agency issuers in `allowed_attempts_providers` and their keys, and for the review app the same block in `identity-eks-control` by merge request (it affects every review app, which is harmless because the feature is still gated by service provider records).
3. **A sandbox seeding path that does not touch `identity-idp-config`.** Because the shared config repo cannot carry keys that `main` does not know, and the Dashboard has no fields, the branch needs its own way to load the fictitious service provider, the agency SPs, their resource servers, scopes and certificates in a sandbox: a rake task (`delegated_access:seed_sandbox`) that reads a YAML file committed on the branch (fictitious agency names, placeholder hosts substituted from the environment) and refuses to run when `Identity::Hostdata.env` is `prod` or `staging`. `token-exchange2`'s seeder already accepts nested resource servers and inline PEM certificates (`TokenExchangeResourceServer#load_cert` reads a PEM string from the `certs` column), so no `certs/sp` file and no `identity-idp-config` change is needed. The same task works in a review app through the Rails console.
4. **Resource server certificates in the database, not on disk.** Follows from 3; the reference agency applications already generate their key pairs with `make rs_keypair`, and the public certificate is pasted into the seed file for the environment.
5. **Reference applications stay where they are.** Nothing in the design has the IdP call an agency or the service provider; agencies call introspection and poll the Attempts API; the service provider calls the token endpoint; the browser does the rest. The three Sinatra applications can therefore run on a developer machine against a sandbox IdP with `localhost` redirect URIs (as `identity-oidc-sinatra` does against `int` today), and the harness runs the same way with `IDP_URL`, the test user and the Attempts poll tokens pointed at the sandbox. Hosting them in the sandbox is a later convenience, not a dependency.
6. **An identity-verified test user in the sandbox.** The harness needs one (`E2E_USER_EMAIL`). A personal environment and a review app both use the mock document-authentication vendor, so proofing a user through the UI once is enough; there is no `rake dev:prime` in deployed environments.
7. **Redis is already there.** The client-assertion `jti` cache, the DPoP `jti` cache, the Attempts buffer and the billing-correlation cache all use the existing `REDIS_POOL`; nothing new to provision.
8. **Workers and reports.** The outcomes report registers in `job_configurations.rb` like every other report and writes to the reports bucket behind `s3_reports_enabled`; on Route B there are no workers, so 5.8's reports are verified on Route A or by running the job from the console.
9. **New public endpoints.** `/api/openid_connect/introspect` and `/api/openid_connect/revoke` are new paths under `/api/openid_connect/`. The WAF rules in `identity-devops/terraform/waf` should be checked once for path allow-lists before the first agency call; the token endpoint's existing rules are the model.
10. **No CORS, no browser endpoint.** Removing `sbx-taigrr`'s `/exchange` CORS rule (5.4) also removes the only infrastructure-visible difference between this branch and `main`'s HTTP surface, apart from the two new paths above.
11. **Schema in the sandbox.** Route A's `agroot` database already has `sbx-taigrr`'s tables; 5.1's drop-and-create migration is what makes a redeploy of the new branch onto it succeed. Route B starts from an empty database every time, so both migration paths get exercised.
12. **Deploy from GitHub.** Until the branch is on GitHub, Route A is closed. The GitLab mirror overwrites diverged branches, so once `login-delegated-access` exists on GitHub, GitHub must be where it is pushed from then on (or the mirror will revert GitLab-only commits). Decide the home of the branch before the first push to GitHub.

---

## 8. Worktrees and sequence

Branch `login-delegated-access` is created from `sbx-taigrr` `0b0539e19` on GitLab `lg/identity-idp` (GitHub needs a push by someone with write access; see 7.4 item 12). Twelve worktrees under `/Users/kylepneuman/coding/worktrees/`, each on a branch of the same name, numbered in dependency order and **stacked**: each feature branch starts from the head of the one before it, so the highest branch always contains every feature below it.

1. `lda-01-onboarding` — data model and configuration (5.1)
2. `lda-02-consent` — authorize request and consent screen (5.2)
3. `lda-03-account` — account page (5.3)
4. `lda-04-exchange` — server-to-server exchange and the shared client authenticator (5.4)
5. `lda-05-lifecycle` — refresh, revocation, suspension and deletion (5.5)
6. `lda-06-introspection` — agency verification (5.6)
7. `lda-07-fraud-signals` — Attempts API delivery (5.7)
8. `lda-08-billing` — billing rows, waiver by adjustment, reports (5.8)
9. `lda-09-saml` — SAML assertions (5.9)
10. `lda-10-dpop` — sender-constrained tokens (5.10)
11. `lda-11-operations` — discovery, analytics sweep, fixtures, test sweep (5.11)
12. `lda-12-biometric` — document images and the passport-agency channel; decisions first (5.12)

Before feature 1: merge `main` into `login-delegated-access` and resolve the one spec conflict (section 2).

How the stack is used:

1. **Integration build.** A pointer branch, `lda-integration`, always names the top of the stack and has no commits of its own. The IdP, the three reference applications and the end-to-end harness run from its worktree, so the whole system is tested without merging anything.
2. **Fixes land in the owning feature.** A problem the harness finds in feature 5.4 is committed on `lda-04-exchange`; one `git rebase --update-refs` from the top re-stacks everything above it and the pointer follows. The branch under review and the tested build are always the same commits.
3. **Acceptance is a fast-forward.** When a feature is accepted, `login-delegated-access` fast-forwards to that feature's head, in order. No cherry-picks and no second copy of the change.
4. **Local before CI.** Pushing any branch to GitLab starts a pipeline and a review app, so no feature branch is pushed until it runs locally: its specs pass and, from 5.4 on, the relevant harness scenarios pass against the local IdP. CI comes after.
5. **Feature branch heads are not stable** until fast-forwarded into `login-delegated-access`, because a change low in the stack rewrites the commits above it. Reviews read the diff between adjacent branches, which the rewrite does not change.

### What needs a go-ahead

1. The `main` merge (section 2).
2. Feature 5.1, including dropping the old grant tables (5.1 Findings 1) and the removal of the application-level allow-list (Findings 2).
3. Features 5.2 to 5.7 and 5.9 to 5.11 as described.
4. Feature 5.8 after the billing decision (5.8 Findings 1 and 2), which also updates the two billing documents and BIL-13.
5. Feature 5.12 after the passport-agency decisions.
6. For the sandbox: who pushes `login-delegated-access` to GitHub, whether to reuse `agroot` or create a new environment, and whether the review-app `application.yml` change can be merged.

---

## 9. Decisions log

### 2026-10-09 interview, feature 5.1 (onboarding data model and configuration)

Decisions taken with Kyle, applied to this document, the functional requirements (amended rows and Appendix D) and the requirements document (§3.4, §4.8, Appendix E rows E37–E45).

1. **D1 — Application = agency SP record; consent per application.** An application is one agency-owned `service_providers` row with consent content, owning one or more resource servers (URLs). A person can approve one application at an agency and not another. Rationale: people think in applications, not agencies. Changes FR-CUX-3 and companion CON-7/CON-10 from agency-level to application-level.
2. **D2 — One scope per application.** The service provider requests `token_exchange:<application scope value>`; the application's URLs are listed for information; `resource` selects one at exchange. The `token_exchange_scopes` table is not built. Rationale: fewer boxes, matches how partners describe an integration.
3. **D3 — Content is edited in the Dashboard.** Agency and application consent content (and service provider content) are Dashboard fields synced by `ServiceProviderUpdater`; production via the seeder. The Dashboard change is a separate repository and an explicit dependency, called out in code comments and in the requirements documents. Until it lands, D10 applies.
4. **D4 — Account-page pre-approval is consent.** The account page lists every registered application that accepts the service provider, grouped by agency; turning one on creates a remembered grant for up to 12 months from that moment; the consent screen honors it.
5. **D5 — Requested applications are take-it-or-cancel.** Applications named in the request appear selected and locked; declining one means cancelling the sign-in, as for requested attributes today. Reverses FR-CUX-4/5 and FR-CEN-6; per-application declines are no longer recorded because none exist.
6. **D6 — The remember choice stays for requested applications.** "Remember my approvals for 12 months", unchecked by default; unchecked means this sign-in only. Account-page pre-approvals are always remembered. FR-CUX-7 and FR-CEN-11 stand.
7. **D7 — Opt-in and approval live on SP records.** `allowed_delegation_service_providers` on the application (empty means any approved service provider); `token_exchange_enabled_sp` on the service provider. The `token_exchange_service_providers` config key is removed; `token_exchange_enabled` remains the master switch.
8. **D8 — Grant key is (user, service provider, application).** One live row, with source, consent time, remember-until, content versions, delegation id, revocation. Not keyed to the service provider identity's session, because pre-approval happens outside any sign-in.
9. **D9 — Only material content changes re-ask.** Every content edit bumps a version; the editor marks it material or not; a material change invalidates remembered grants for that application (or for everything under that agency or service provider). Narrows FR-CEN-5 and CON-12.
10. **D10 — Branch seed file and env-guarded rake task** for local, review-app and sandbox data until the Dashboard fields exist; the dependency is stated explicitly in comments and documents.
11. **D11 — Full terminology sweep in 5.1.** Every "broker" identifier, string and comment, and every public-client or browser-callable comment, is corrected in 5.1 even in code later features delete.
12. **D12 — Agency-level content lives on `agencies`.** Localized description and learn-more URL alongside the existing name and logo, editable on the Dashboard's agency record.

**Effect on later features.** Sections 5.4 to 5.11 still describe scopes per API in places (for example "a grant for that API" in 5.4 and `scope` handling in 5.6). Each is reconciled with D1/D2 at that feature's own interview before implementation; the exchange still issues a token for exactly one resource server URL of an approved application.

**Open after the interview:** "approve all" control (not needed: requested applications are locked); whether the account page should offer applications under service providers the person has never connected to (deferred, 5.3 Findings 1); the mockup revision for locked rows (5.2 Findings 2).
