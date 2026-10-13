# ADR 0001: Account-Preserving MFA Recovery

- Status: Proposed
- Date: 2026-10-07
- Decision owners: Tem Katherine
- Scope: Non-identity-proofed users who have authenticated with their password but cannot access any configured MFA method

## Context

Login.gov currently offers an account reset workflow to users who successfully authenticate with
their password but cannot complete MFA. The workflow waits for a configured period, sends a
time-limited email link, and ultimately deletes the account. The user must then create a new
account, and the original account identifier and relying-party relationships are not preserved.

The current implementation is centered on:

- [`AccountReset::RequestController`](../../app/controllers/account_reset/request_controller.rb)
- [`AccountReset::CreateRequest`](../../app/services/account_reset/create_request.rb)
- [`GrantAccountResetRequestsAndSendEmailsJob`](../../app/jobs/grant_account_reset_requests_and_send_emails_job.rb)
- [`AccountReset::DeleteAccount`](../../app/services/account_reset/delete_account.rb)
- [`AccountResetRequest`](../../app/models/account_reset_request.rb)

The new workflow needs to preserve the existing user account while allowing the user to replace
inaccessible MFA methods. It must coexist with the existing destructive account reset while the
new workflow is developed, evaluated, and rolled out. Existing account reset requests must never
be silently converted to the new workflow.

In this application, an IAL1 user is generally a user without an active identity-proofed profile.


## Decision drivers

- Preserve the user's stable account identifier and relying-party relationships.
- Prevent an email magic link from becoming an MFA bypass by itself.
- Keep the recovery authorization narrower than a normal authenticated session.
- Preserve inaccessible MFA records until replacement MFA has been verified.
- Revoke inaccessible MFA as part of successful completion.
- Keep the current destructive account reset available as a control and fallback during rollout.
- Preserve in-flight requests for both workflows during deploys, rollback, and configuration
  changes.
- Provide enough durable state and privacy-preserving telemetry to reconstruct a recovery path and
  compare it with the legacy path.
- Support a rapid rollout stop without corrupting or abandoning active recovery attempts.

## NIST baseline

This decision is based on the final NIST SP 800-63 Revision 4 guidance published in 2025:

- [SP 800-63B-4](https://doi.org/10.6028/NIST.SP.800-63b-4)
- [Account recovery](https://pages.nist.gov/800-63-4/sp800-63b.html#recovery)
- [Recovery without identity proofing](https://pages.nist.gov/800-63-4/sp800-63b.html#recovery-without-identity-proofing)
- [Recovery at AAL2](https://pages.nist.gov/800-63-4/sp800-63b.html#recovery-at-aal2)
- [Post-enrollment authenticator binding](https://pages.nist.gov/800-63-4/sp800-63b.html#post-enroll-bind)
- [Account notifications](https://pages.nist.gov/800-63-4/sp800-63b.html#notification)

For an account that can authenticate at a maximum of AAL2, SP 800-63B-4 requires one of:

1. Two recovery codes obtained through different recovery method classes.
2. One recovery code plus authentication with an existing bound single-factor authenticator.
3. Repeated identity proofing when the account was previously identity-proofed.

This workflow uses the second option:

- The existing password is the bound single-factor authenticator.
- The delayed email magic link represents an issued recovery code.

The waiting period is a supplemental fraud control. It is not a recovery factor and does not
increase the assurance of the email link.

## Decision

We will build a separate account-preserving MFA recovery workflow for eligible non-proofed users
who have successfully authenticated with their password but cannot access any configured MFA
method.

The workflow will require both:

1. A single-use recovery link sent to a previously confirmed email address after a waiting period.
2. Fresh authentication with the existing password when the recovery link is redeemed.

Satisfying these requirements will create a short-lived, server-side recovery authorization. It
will not create a normal signed-in session. The authorization will permit only enrollment and
verification of replacement MFA, cancellation, and sign-out.

After replacement MFA is verified, the system will atomically:

1. Activate the replacement MFA.
2. Revoke the inaccessible old MFA methods.
3. Consume the recovery authorization and all tokens for the request.
4. Invalidate concurrent recovery sessions for the request.
5. Apply the approved policy to existing authenticated and remembered-device sessions.
6. Persist security events and analytics outcomes.
7. Send account recovery, authenticator binding, and authenticator revocation notifications.

The user will then complete a fresh normal sign-in using the password and replacement MFA.

## Eligibility

The treatment workflow is available only when all of the following are true:

- The user has completed password authentication in the current sign-in flow.
- The user has reached the MFA challenge and has at least one configured MFA method.
- The user reports that none of the configured MFA methods are accessible.
- The user is fully registered.
- The user has no active identity-proofed profile.
- The user has no pending proofing, password-reset profile, or other state that requires a separate
  profile recovery policy.
- The user has at least one previously confirmed email address eligible for recovery delivery.
- The account is not suspended, fraud-restricted, or otherwise excluded by recovery policy.
- The requested service provider does not impose an authentication requirement that this workflow
  cannot safely restore.
- The feature is enabled and the user is assigned to the treatment.

Eligibility is enforced on the server at request creation, link redemption, password
reauthentication, replacement MFA binding, and completion. A decision made while rendering a page
is not sufficient authorization for a later transition.

This workflow does not support:

- Anonymous recovery initiated only through an email address.
- A user who cannot successfully authenticate with the existing password.
- A newly reset password obtained through the same email channel being treated as an independent
  previously bound authenticator.
- Identity-proofed account or profile recovery. See
  [Identity-proofed (IDV) users](#identity-proofed-idv-users).
- Support-assisted overrides that do not satisfy the recovery evidence requirements.

## Identity-proofed (IDV) users

Identity-proofed users are out of scope for this decision. They continue to follow the existing
recovery paths without behavior changes.

An IDV user is any user with an active profile, or with a pending, password-reset, or otherwise
non-active profile that requires profile recovery or reactivation (for example, GPO, in-person, or
fraud-review pending states).

Rules:

- IDV users are never assigned to the treatment bucket and never create account-preserving
  recovery records.
- When an IDV user selects recovery from the post-password MFA challenge, the existing destructive
  account reset runs unchanged: same routes, records, wait period, fraud-user wait period, mailers,
  job, cancellation behavior, and analytics events.
- Password reset, personal key sign-in, personal key reactivation, and re-verification flows are
  unchanged. This ADR does not alter profile encryption, deactivation, or reactivation behavior.
- The new workflow never reads, decrypts, activates, deactivates, or deletes a profile.
- The existing path is destructive and is retained for IDV users as current behavior, not as the
  desired end state. Account-preserving recovery for IDV users needs a separate ADR. That decision
  must address repeated identity proofing consistent with the original proofing level, confirmation
  that the claimant matches the existing profile, personal key and profile-encryption continuity,
  and assurance-level preservation.

Boundary handling:

- Proofing status is evaluated on the server at request creation and again at link redemption,
  password reauthentication, replacement MFA binding, and completion.
- If a user becomes IDV after a treatment request starts (for example, a profile is activated or a
  pending profile is created during the waiting period), the next transition fails closed. The
  request is cancelled with the bounded reason `ineligible_idv_profile`, no MFA is modified, and the
  user is directed to the existing path. The user receives a cancellation notification.
- A user in treatment who previously had no profile is not retroactively counted as a treatment
  failure when this occurs. The event is recorded as an exclusion.
- Legacy requests created by a non-IDV user who later becomes IDV continue through the legacy path
  as they do today.
- Flag, bucket, or kill-switch changes never route an IDV user into treatment.

Telemetry:

- Eligibility events record `eligibility_reason` values such as `identity_verified` and
  `pending_profile`, without profile or identity data.
- IDV users are excluded from treatment-versus-control analysis. Their legacy events remain
  comparable with the historical series.

## Architecture

### Separate persistence

The account-preserving workflow will use a new recovery record rather than changing the meaning of
`AccountResetRequest`. The legacy record and services will remain unchanged during rollout.

The new record will persist:

- User association.
- Flow variant and rollout assignment.
- Request generation.
- Request, grant, password verification, completion, cancellation, expiration, and supersession
  timestamps.
- The requesting service provider, when applicable.
- A fingerprint of the active magic-link token rather than the raw token.
- Token issuance and expiration timestamps.
- Recovery authorization generation and expiration.
- Selected replacement MFA method.
- The old MFA methods selected for revocation.
- Bounded terminal and failure reason codes.

Only one active account-preserving recovery request may exist per user. Creating a new request
atomically supersedes the prior request and invalidates its token and recovery authorizations.

### Recovery token

The email recovery token will:

- Contain at least 128 bits of entropy from an approved secure random generator.
- Be encoded in a URL-safe representation.
- Be stored only as a keyed fingerprint or approved one-way hash.
- Be bound to the user, recovery purpose, request generation, and flow variant.
- Be valid for no more than 24 hours after issuance.
- Be single-use and consumed atomically.
- Be invalidated on cancellation, completion, expiration, or supersession.
- Be protected by per-account and per-network validation throttles.
- Never be included in analytics, operational logs, referrers, or exception messages.

### Recovery authorization

Successful link validation does not sign the user in. It creates or advances a recovery
authorization that is:

- Stored server-side.
- Bound to the recovery request, user, request generation, and browser session.
- Short-lived.
- Marked with magic-link and fresh-password verification timestamps.
- Restricted to approved MFA setup and recovery cancellation routes.
- Invalid after completion, cancellation, expiration, supersession, password change, or generation
  mismatch.

The normal MFA setup guard in
[`MfaSetupConcern`](../../app/controllers/concerns/mfa_setup_concern.rb) will not be weakened.
Recovery-aware controllers will use a dedicated authorization policy and reuse existing MFA setup
forms and services without granting general partial sessions access to setup.

The recovery authorization cannot:

- Release a relying-party assertion.
- Access the account page or protected profile data.
- Change email addresses or password.
- Create or extend remember-device authorization.
- Remove MFA outside the controlled completion transaction.
- Be treated as a normal AAL2-authenticated session.

## State transitions

Routing, sequence, state, authorization, and telemetry diagrams are in
[ADR 0001 Flows](./0001-account-preserving-mfa-recovery-flows.md).

```text
requested
  -> waiting
  -> granted
  -> link_verified
  -> password_verified
  -> replacement_mfa_pending
  -> completed

requested | waiting | granted
  -> cancelled
  -> expired
  -> superseded

link_verified | password_verified | replacement_mfa_pending
  -> cancelled
  -> expired
  -> superseded
```

Terminal states cannot transition back to an active state. Transition checks and their associated
mutations will occur under a database lock or equivalent atomic operation.

## Existing MFA lifecycle

The old MFA methods will not be deleted when recovery is requested.

During the waiting period:

- Existing MFA remains usable.
- Successful normal MFA authentication cancels or supersedes the recovery request.
- The user may cancel through a password-authenticated pending page or a cancellation link.

After the magic link and fresh password are verified:

- The inaccessible MFA records are retained for auditability and atomic completion.
- They are marked pending revocation and are suspended from authorizing new sign-ins.
- A partially configured replacement method does not become active.

At successful completion:

- The replacement method is activated.
- The inaccessible old methods are revoked in the same transaction.
- The recovery request is completed and cannot be replayed.

If replacement setup fails or is abandoned, no partially configured method is activated. Because
the user declared the old methods inaccessible and they may be compromised, suspended methods are
not automatically restored merely because recovery setup expired. The user may retry while valid
recovery evidence remains or start a new request.

### Implementing the suspended (inactive) state

Today an MFA configuration has no inactive state. A method is usable when its row exists, subject
to type-specific checks such as `mfa_enabled?` and `BackupCodeConfiguration.unused`. Removal is a
hard delete through the existing delete forms, for example
`TwoFactorAuthentication::WebauthnDeleteForm#submit` calling `configuration.destroy`.
`MfaContext` is not the only reader: the `phone_configurations`, `webauthn_configurations`,
`piv_cac_configurations`, `auth_app_configurations`, and `backup_code_configurations` associations
are referenced directly from roughly 78 files in `app/` and `lib/`.

Because of this, suspension will not be modeled by changing the existing configuration tables.

**Decision: a recovery-owned suspension ledger enforced at authentication boundaries.**

1. Add one new table owned by the recovery feature (proposed name
   `account_recovery_mfa_suspensions`):
   - `account_recovery_request_id`, `user_id`
   - `configuration_type` (bounded enum: `phone`, `webauthn`, `piv_cac`, `auth_app`,
     `backup_code`) and `configuration_id`
   - `suspended_at`, `revoked_at`, `released_at`
   - Non-sensitive descriptors only, such as method type and platform-authenticator flag. No phone
     numbers, credential IDs, public keys, OTP secrets, code digests, or names are copied.
   - No foreign key to the configuration tables, so the audit row survives the configuration
     being destroyed at completion.
   - Columns carry the repository's `sensitive=` schema comments. The migration is additive and
     needs no backfill.
2. At the `password_verified` transition, in the same locked transaction as the state change:
   - Insert one suspension row for each old configuration in scope. This is all MFA unless the
     open decision on user-designated revocation changes it.
   - Revoke remember-device authorization with `ForgetAllBrowsers`. A remember-device cookie
     bypasses the MFA challenge, so waiting until completion would leave a suspended method
     effectively usable.
   - Leave the configuration rows untouched. Nothing is deleted at this point.
3. A single query object (proposed `AccountRecovery::MfaSuspension`) answers
   `suspended?(user)` and `suspended_configuration?(configuration)`. Every enforcement point
   uses it, and it fails closed: if suspension state cannot be read, authentication is denied
   rather than allowed.
4. Enforcement points. Every one needs a regression spec.
   - **Post-password routing.** If the user has active suspensions, the user goes to recovery
     continuation instead of the MFA challenge. `MfaPolicy` still reports MFA as enabled, so
     this check must run before the existing two-factor redirect.
   - **MFA verification.** A shared guard runs before the existing two-factor verification
     controllers (phone OTP, TOTP, WebAuthn, PIV/CAC, backup code). As defense in depth,
     `handle_valid_verification_for_authentication_context` refuses to mark the session
     authenticated for a suspended configuration.
   - **OTP delivery.** `/otp/send` and resend paths do not send codes to suspended phones. This
     prevents SIM-swap use and avoids telephony cost.
   - **Passwordless PIV/CAC sign-in.** `Users::PivCacLoginController` signs a user in without a
     password, so the PIV/CAC login form rejects a suspended `x509_dn_uuid`.
   - **Selection and options presenters.** Suspended methods are not offered as sign-in choices.
   - **Account management.** This is unreachable because no full session exists, and the
     recovery-limited authorization separately denies edit and delete routes.
5. `MfaContext` counts and `MfaPolicy` remain unchanged. Changing them globally would alter
   analytics, setup requirements, and account pages for every user. Suspension is enforced at
   the boundaries above instead of by filtering every association reader. A `default_scope` on
   the configuration models is explicitly rejected.

**Completion: one transaction, revoke before activate.**

The replacement method is not persisted as a separate inactive configuration. The final
verification request of the replacement setup (OTP confirmation, TOTP code, WebAuthn attestation,
PIV/CAC certificate) calls the completion service. In one transaction with the user and request
rows locked, the completion service:

1. Re-checks the request state, expiry, and recovery authorization.
2. Destroys the suspended old configurations. It reuses the existing deletion forms or services
   so that user `Event` records, push notifications, and analytics stay identical to a
   user-initiated removal. Backup codes are removed as a set.
3. Sets `revoked_at` on each suspension row.
4. Creates the replacement configuration through the existing setup form.
5. Marks the request `completed`, consumes the token, and invalidates other recovery
   authorizations.

Old rows are deleted before the replacement is inserted. This avoids collisions with the existing
unique indexes on `piv_cac_configurations` (`x509_dn_uuid`, `user_id`/`name`) and
`auth_app_configurations` (`user_id`/`name`). If the user re-enrolls the same PIV/CAC card or
reuses a name, a retained row would otherwise make the insert fail.

Any failure rolls back the whole transaction. The old rows stay suspended, no replacement exists,
and the user may retry while the recovery authorization is valid. Email notifications are
enqueued only after commit.

**Expiry, cancellation, and release.**

- Suspension rows from an expired or cancelled request stay in effect (`released_at` stays
  `nil`). A new request for the same user adopts the existing suspensions instead of creating
  duplicates.
- `released_at` is set only by an explicitly approved path, such as a support procedure or a
  policy decision. It is never set automatically, and setting it is a logged, notified event.
- After completion, suspension rows are kept as audit history per the retention policy. They
  feed `bin/summarize-user-events` and analytics `old_mfa_disposition`.

**Out of scope.** The personal key (`PersonalKeyConfiguration`, backed by
`encrypted_recovery_code_digest`) belongs to identity-proofed profiles. IDV users are excluded
from this workflow, so it is not suspended or revoked here.

## Legacy workflow coexistence

The existing destructive account reset remains available throughout implementation and rollout.
It continues to use its existing routes, records, mailers, job, cancellation behavior, and
analytics events.

Routing between workflows occurs only when an eligible user selects recovery from the post-password
MFA challenge:

- Control or feature disabled: use the legacy destructive account reset.
- Treatment and eligible: use account-preserving MFA recovery.
- Identity-proofed (IDV) user: always use the legacy path, regardless of flag or bucket.
- Other ineligible users: use the legacy path or an explicit unavailable-recovery outcome according
  to product policy.

The selected flow is persisted when a request is created. Later feature flag or experiment changes
do not move an in-flight request to the other workflow.

Specific coexistence rules:

- Existing `AccountResetRequest` rows always finish through the legacy path.
- New account-preserving recovery records always finish through the new path.
- A user cannot have active requests in both workflows.
- Starting one workflow atomically cancels or rejects an active request in the other workflow.
- Legacy routes do not accept new-flow tokens, and new routes do not accept legacy tokens.
- Jobs query only their own record type and state.
- Notifications clearly identify whether the result is account deletion or MFA recovery.
- The account-preserving flow never calls `AccountReset::DeleteAccount`.

The legacy implementation will not be removed until:

- Treatment has reached the approved rollout level.
- Security and product guardrails have remained acceptable for the agreed observation period.
- No in-flight legacy requests remain, based on the maximum wait and token-validity periods.
- IDV users have an approved replacement path under a separate decision.
- Support and incident procedures cover the new workflow.
- A separate cleanup decision approves removal.

## Feature rollout

Rollout will use two controls.

### Kill switch

A global feature setting controls creation of new account-preserving recovery requests.

Turning it off:

- Routes newly eligible users to the legacy flow.
- Does not reinterpret or delete active new-flow requests.
- Allows active requests to complete, cancel, or expire unless an incident-specific hard stop is
  separately enabled.

An incident hard stop may block link redemption and completion, but must preserve state and provide
a safe user-facing outcome. It must not silently report success.

### Persistent treatment assignment

A persisted A/B assignment uses the user UUID as its discriminator:

- Control bucket: legacy destructive account reset.
- Treatment bucket: account-preserving MFA recovery.

The assignment is stable across browsers, sessions, and the waiting period. Relevant legacy and
new analytics events include the assignment through the existing analytics A/B test integration.
Ineligible users are excluded from treatment analysis rather than counted as treatment failures.

## Notifications

Notifications are sent for:

- Recovery request creation.
- Magic-link issuance.
- Recovery cancellation.
- Recovery expiration when operationally appropriate.
- Magic-link and password evidence acceptance.
- Replacement MFA binding.
- Old MFA revocation.
- Recovery completion.

Notifications are sent to all applicable stored notification addresses as required by policy. A
recovery completion notification is separate from the email carrying the recovery code and
contains clear instructions for repudiating unauthorized recovery.

No notification contains passwords, MFA secrets, raw recovery tokens other than the intended
single-use link, or sensitive account/profile data.

## Telemetry and audit history

Transactional state is the source of truth for recovery correctness. Persistent user security
events provide an account history. Analytics events measure aggregate behavior and rollout
outcomes.

Recovery analytics include:

- `Account Recovery: options visited`
- `Account Recovery: eligibility evaluated`
- `Account Recovery: request`
- `Account Recovery: granted`
- `Account Recovery: link validation`
- `Account Recovery: password verification`
- `Account Recovery: MFA setup started`
- `Account Recovery: MFA setup submitted`
- `Account Recovery: old MFA revoked`
- `Account Recovery: completed`
- `Account Recovery: cancelled`
- `Account Recovery: expired`

Existing legacy event names remain unchanged so historical series remain valid.

Event properties are bounded and documented, such as:

- `success`
- `failure_reason`
- `flow_variant`
- `recovery_state`
- `recovery_evidence`
- `replacement_mfa_method`
- `old_mfa_disposition`
- `eligibility_reason`
- `elapsed_time_bucket`

Analytics do not include raw tokens, email addresses, phone numbers, passwords, MFA secrets,
user-entered credential values, or free-form error messages. Existing analytics context supplies
the user, path, service provider, and experiment assignment where available.

The primary treatment metric is:

```text
distinct eligible users who successfully sign in with replacement MFA
----------------------------------------------------------------------
distinct eligible users who initiate account-preserving recovery
```

Guardrail metrics include:

- Repudiated or disavowed recovery notifications.
- Invalid, expired, replayed, and concurrently redeemed links.
- Password verification failures.
- Request and validation rate limiting.
- Recovery cancellation and expiration.
- Use of an old MFA method after completion.
- Unexpected relying-party assertions during recovery.
- Rapid email or password changes after recovery.
- Legacy deletion fallback and support contact rates.

Support-facing event summarization will show the ordered legacy or account-preserving path without
exposing recovery secrets.

## Session policy

The implementation must define and test:

- Invalidation of other recovery sessions at completion.
- Behavior of existing fully authenticated sessions.
- Behavior of remember-device cookies.
- Pending relying-party requests.
- Password changes during waiting or setup.
- Successful use of an old MFA method during waiting.
- Recovery links opened in a different browser.
- Cancellation while replacement setup is in progress.

At minimum, recovery completion invalidates remember-device authorization and requires a fresh
normal sign-in. The final policy for other existing authenticated sessions must be approved before
implementation is enabled.

## Security invariants

- No recovery request can be initiated without successful password authentication.
- A magic link alone cannot replace MFA or create an authenticated session.
- Recovery requires a valid issued recovery link and fresh authentication with the existing
  password.
- Password reset through the same email channel is not treated as possession of a previously bound
  password for this workflow.
- Only eligible non-proofed users can enter treatment.
- Recovery authorization is purpose-bound and cannot reach normal authenticated surfaces.
- Replacement MFA is verified before activation.
- Old MFA is not revoked until replacement MFA is verified.
- Replacement activation, old-factor revocation, and recovery completion are atomic.
- Every token and authorization is generation-bound, expiring, and non-replayable.
- Cancellation, expiration, supersession, concurrent use, and rollback fail closed without
  success-shaped responses.
- Account recovery and authenticator changes cause independent notifications.

## Consequences

### Positive

- Users can retain their account identifier and relying-party relationships.
- Recovery evidence has a direct mapping to the NIST AAL2 recovery requirements.
- A compromised email account alone is insufficient to replace MFA.
- The legacy flow provides a control, fallback, and rollback path during rollout.
- Existing MFA setup logic can be reused behind a narrower authorization boundary.
- Durable transitions and stable experiment assignment support support investigations and product
  evaluation.

### Negative

- A new persistent workflow, token lifecycle, authorization context, and job are required.
- MFA configuration types need a consistent suspension and revocation strategy.
- Cross-browser recovery and session invalidation increase implementation and test complexity.
- Users who also lost their password remain ineligible.
- IDV users remain on the destructive legacy path until a separate decision is approved, so the
  legacy flow cannot be retired by this ADR alone.
- Users with suspended old MFA may remain unable to sign in if replacement setup is abandoned.
- Legacy and treatment workflows must be operated and monitored simultaneously during rollout.

### Risks

- A broad exception to existing MFA setup guards could create an MFA bypass.
- Failure to atomically revoke old MFA could leave compromised authenticators active.
- Feature changes could strand users if in-flight flow ownership is not persisted.
- Conflating product analytics with authoritative recovery state could produce incorrect security
  decisions.
- Treating the waiting period as recovery evidence would overstate the workflow's assurance.

## Alternatives considered

### Email magic link without password reauthentication

Rejected. The initial password authentication may be stale after the waiting period, and email
control alone must not become sufficient to replace MFA.

### Two issued codes delivered by email and SMS

Rejected as the default NIST rationale. They remain the same issued recovery-code method class and
do not automatically satisfy the two-different-methods option.

### Delete old MFA when recovery is requested

Rejected. A claimant with only the password could cause immediate denial of service, and a failed
replacement setup would leave the account without a usable MFA method.

### Add a status column to each MFA configuration table

Rejected. This would require five migrations on large tables, a status-aware audit of roughly 78
direct association call sites, and either a `default_scope` or an easily missed filter at every
read. Any missed reader would silently treat a suspended method as active. The existing unique
indexes would also block re-enrolling the same PIV/CAC card or reusing a name.

### Move old configurations to archive tables at suspension

Rejected. Copying secret-bearing rows (OTP secrets, credential public keys, phone numbers)
duplicates sensitive data. It also turns rollback into a data-restoration problem rather than a
simple state change.

### Keep old MFA active after recovery completes

Rejected. The user declared the methods inaccessible, and they may be compromised.

### Modify `AccountResetRequest` to support both deletion and recovery

Rejected. Overloading the existing record and token lifecycle would increase the risk of routing a
request to the wrong terminal action and make rollback and in-flight request handling ambiguous.

### Immediately replace the legacy flow

Rejected. The new flow needs a controlled rollout, measurable comparison, operational readiness,
and a safe fallback.

## Implementation phases

1. Add separate persistence, state transitions, token handling, and eligibility policy behind a
   disabled feature.
2. Add request, waiting, cancellation, grant, and notification behavior without enabling MFA
   mutation.
3. Add the recovery authorization and fresh password verification.
4. Add the suspension ledger and every authentication-boundary enforcement point, with specs,
   before any request can reach `password_verified`.
5. Integrate approved MFA setup methods and atomic replacement/revocation.
5. Add security events, analytics, support summarization, dashboards, and alerting.
6. Run internal and synthetic end-to-end validation.
7. Enable a small persisted treatment cohort while retaining the legacy control.
8. Expand only when conversion and security guardrails meet approved thresholds.
9. Stop new legacy assignments for eligible non-IDV users after full approval. IDV users continue
   to use the legacy path, in-flight legacy requests are allowed to reach a terminal state, and
   legacy removal is a separate decision.

## Acceptance criteria

- An anonymous user cannot initiate recovery.
- A password-authenticated user can initiate recovery only from the MFA challenge.
- A valid magic link without fresh password verification cannot access MFA setup.
- Fresh password verification without a valid magic link cannot access MFA setup.
- A recovery authorization cannot access account settings, profile data, or a relying party.
- Proofed and pending-proofing users cannot enter treatment.
- IDV users selecting recovery reach the unchanged legacy account reset regardless of flag or bucket.
- A user who becomes IDV mid-flow has the treatment request cancelled with no MFA mutation and is
  directed to the existing path.
- The new workflow performs no profile reads, decryption, activation, deactivation, or deletion.
- Password reset, personal key, and profile reactivation behavior for IDV users is unchanged.
- Tokens are hashed, single-use, expiring, throttled, and atomically consumed.
- Replayed, superseded, cancelled, and expired tokens cannot mutate MFA.
- A replacement method must be verified before it is active.
- Old methods remain persisted until replacement verification succeeds.
- Successful completion atomically activates the replacement and revokes inaccessible old methods.
- After `password_verified`, a suspended configuration cannot complete MFA verification, receive
  an OTP, sign in through passwordless PIV/CAC, or be honored through remember-device. Each
  enforcement point has a regression spec.
- If suspension state cannot be read, authentication is denied.
- A failure anywhere in the completion transaction leaves old configurations suspended and
  persisted, with no replacement created.
- Re-enrolling the same PIV/CAC card or reusing an auth-app name succeeds during completion
  without unique-index conflicts.
- Revoking old configurations emits the same user events and push notifications as existing
  user-initiated removal.
- Suspensions from expired or cancelled requests are never automatically released.
- Concurrent completion attempts produce exactly one successful terminal transition.
- Normal use of an old MFA method during waiting cancels or supersedes recovery.
- Completion invalidates recovery sessions and remember-device authorization.
- Feature disablement routes new users to legacy without corrupting active treatment requests.
- In-flight legacy requests always complete through the legacy flow.
- Analytics distinguish control and treatment without logging credentials, tokens, or PII.
- A successful post-recovery sign-in is measurable as the final funnel outcome.

## Open policy decisions

The following decisions must be resolved before implementation is enabled:

- Exact waiting period and whether risk signals may lengthen, but never shorten, it.
- Which confirmed email addresses qualify as recovery addresses.
- Which replacement MFA methods are permitted in the initial release.
- Whether all old MFA methods or only user-designated inaccessible methods are revoked.
- Treatment of existing fully authenticated sessions at recovery completion.
- Expiration and retry behavior after old MFA has been suspended, including who may set
  `released_at` and under what evidence.
- Whether a replacement may reuse a phone number or device the user declared inaccessible.
- Retention period for suspension audit rows.
- Fraud and account-status exclusions.
- Rollout thresholds, observation period, and incident hard-stop behavior.
- Support procedures for users who cannot complete this workflow.
- Timing and ownership of the separate ADR for account-preserving recovery of IDV users.
- Whether IDV users should be told, before requesting recovery, that the existing path deletes the
  account and profile.

