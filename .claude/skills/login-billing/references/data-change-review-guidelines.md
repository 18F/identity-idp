<!-- Vendored from the data team's docs/data-change-review-guidelines.md on the `token-exchange2-login`
branch (fetched 2026-10-10), quoted as written so none of the data team's reasoning is lost. The text
uses the source's own vocabulary ("broker"); the stack's vocabulary is "service provider". Where this
guidance and the product owner's decisions differ, SKILL.md section 2 says which wins and why. -->

# Data Change Review Guidelines

## Purpose

Use this guide as a data-review proxy for merge requests that add or modify:

```text
database tables or columns
log tables or durable event records
token storage
billing/reporting evidence
analytics events
Attempts API event schemas
cache-backed flow state
```

The review goal is to keep durable data stores narrow, intentional, and aligned to their true purpose. Temporary state should not become permanent database state by default. Audit-only observations should not become database columns by default. Existing analytics and Attempts event shapes should remain stable for downstream consumers.

## Review Output Contract

A data review should produce these sections:

```text
Summary
  Short statement of what data is being added or changed.

Decision
  approve / approve with changes / block

Findings
  Ordered list of concrete risks or required changes.

Persistence assessment
  Whether each new persisted value is required, cacheable, log-only, or unnecessary.

Sensitivity assessment
  Whether fields/events are PII, sensitive, digests, opaque IDs, or non-sensitive.

Analytics and Attempts assessment
  Whether event changes preserve shape and avoid PII.

Data team notification
  Whether data team notification is required and why.

Required tests or guardrails
  CI/spec checks needed to prevent drift.
```

## Priority Rules

Apply these rules in order:

```text
1. Protect PII and sensitive data.
2. Preserve immutable logs.
3. Keep billing and reporting grain stable.
4. Minimize durable persistence.
5. Preserve analytics and Attempts event shape.
6. Notify data team for downstream modeling awareness.
```

## Decision Procedure

For each proposed field/table/event/cache entry, answer in order:

```text
1. What exact product, security, billing, or operational requirement needs this data?
2. Does it need to survive session expiry, cache expiry, deploys, retries, or audit replay?
3. Is the data only needed for a short-lived flow window?
4. Is the data only needed for audit/troubleshooting?
5. Is the proposed table the narrow owner of this concept?
6. Does the change alter the grain of an existing identifier or report?
7. Could the data contain PII or credentials now or in future values?
8. Does the change affect analytics or Attempts downstream schemas?
9. What test fails if this write path stops working?
```

Use the first matching storage recommendation:

```text
short-lived flow state -> TTL cache or session-bound storage
audit-only observation -> analytics/logging, not DB
PII/proofing event -> Attempts API path and schema, not analytics
durable billing interpretation -> append-only adjustment/evidence table
new business entity -> narrow purpose-built table
existing broad table -> only if it already owns the concept
log table -> append only; never mutate prior meaning
```

## Immutable Logs

Log-like tables must be treated as append-only.

Do not:

```text
update prior log rows to change their meaning
flip a prior row from billable to non-billable
reclassify a prior row after a later event occurs
reuse log rows as workflow state
store temporary correlation data in log rows
```

Do:

```text
write a new log row for a new event
write an append-only adjustment when later facts change billing interpretation
preserve the original event exactly as it happened
```

A table should be treated as a log when its name, use, or reporting role implies event history, even if no formal immutability constraint is documented.

## Table Purpose And Ownership

Before adding columns to an existing table, identify the table's core responsibility.

Block or challenge changes that add narrow feature state to broad tables such as:

```text
users
identities
service_providers
sp_return_logs
profiles
```

Ask:

```text
Is this table the owner of this concept?
Is the data required for the table's primary query path?
Would this column turn the table into workflow/session state?
Would this column couple unrelated domains?
Can a cache, log event, adjustment table, or narrow feature table own this instead?
```

Strong default:

```text
Do not expand broad tables unless the new field is central to that table's existing concept.
```

## Durable Persistence Minimization

Persist only data that must be queryable or replayable after cache/session expiry.

Prefer this hierarchy:

```text
1. Derive safely from existing durable data.
2. Use TTL cache or session-bound storage.
3. Use analytics/logging for audit-only observations.
4. Add append-only adjustment/evidence for durable billing interpretation.
5. Add a narrow purpose-built table.
6. Add columns to broad existing tables only as a last resort.
```

Do not add durable DB fields because data is convenient to inspect later. Convenience alone is not a persistence requirement.

Exception: in a narrow append-only evidence table, a small number of redundant snapshot fields may be acceptable when they materially improve human auditability or operational readability. This exception only applies when:

```text
the table is purpose-built and narrow
source-of-truth foreign keys are also stored
the duplicated values are stable identifiers, not PII or credentials
the duplicated values do not change billing/reporting grain
the MR documents why the redundant snapshot improves review, support, or audit workflows
reports continue to rely on canonical keys or documented snapshot semantics
```

Examples that can be acceptable in an append-only billing adjustment table:

```text
broker_issuer copied from the adjusted broker return row
target_issuer copied from the related delegated return row
```

Examples that remain disfavored:

```text
raw tokens
raw session IDs
PII attributes
resource/audience details not needed for the billing decision
mutable status copied from broad state tables
```

## Cache And Session-Bounded State

Use TTL cache or session-bound storage when data only needs to bridge near-term steps or only needs to live for the user's active AAL/session window.

Good cache candidates:

```text
short-lived request correlation
one-time token-to-return lookup windows
temporary handoff state
retry windows bounded by product-approved TTLs
session-bounded delegated token lookup
session-bounded token refresh or rotation state
```

Cache design must define:

```text
cache key
cache value
TTL
cache-hit behavior
cache-miss behavior
invalidation on logout
invalidation on session expiry
invalidation on re-authentication
whether cache loss affects user experience, billing, or security
logging/alerting for cache misses
```

When cache backs token or delegation state, TTL should align with the user's session/AAL authentication window. After cache expiry, logout, or session expiry, the user should re-authenticate or re-authorize delegation rather than relying on persisted token state.

Do not silently fall back to imprecise database inference unless explicitly accepted in the MR.

## Token State

Token tables can grow quickly. Persist token records only when the lifecycle requirement must survive beyond cache/session storage.

If token access and delegated authorization are bounded to the user's normal AAL/session timeout, durable token persistence is disfavored.

Strong default:

```text
Use TTL cache or session-bound storage for session-bounded token lookup, refresh, and rotation.
Require re-authentication/re-authorization after session expiry.
```

Potential reasons to persist token state are limited to cases such as:

```text
opaque token introspection that cannot be satisfied from cache/session storage
refresh-token rotation that intentionally survives beyond a single session/cache entry
revocation lists that must be queryable after cache/session expiry
replay detection with durability requirements beyond the active session
formal security/audit requirement for durable token lifecycle records
```

If a token table remains, require:

```text
retention period tied to token/session lifetime
pruning job or partition expiration
indexes for hot lookup and pruning paths
expected row-growth estimate under peak volume
field-by-field justification
sensitive values stored as digests only
specs proving expired/revoked/pruned tokens cannot be used
```

## Billing Grain

Billing data must stay at contractual billing grain.

For issuer-based billing:

```text
issuer = application integration grain
one issuer maps to one service_provider/integration
issuer must not encode resource, audience, scope, product, or API variants
```

Do not:

```text
prepend or append resource data to issuer
create issuer variants for target resources
derive target billing from most-recent return logs
store lower-level resource/audience data in billing tables unless required for a concrete billing decision
```

Do:

```text
store broker_issuer and target_issuer at issuer grain
map target billing through existing issuer/integration/order relationships
store lower-level operational token data only in token-exchange-specific storage if required
```

## Operational State Versus Billing Evidence

Separate operational token state from billing evidence.

Operational state answers:

```text
Can this token be used?
Who may introspect it?
Is it expired or revoked?
Which scopes are active?
```

Billing evidence answers:

```text
Which event/return should be included or excluded from invoiceable usage?
Why was that billing decision made?
What later event caused the adjustment?
```

Do not make invoice reports depend on token-exchange internals when a narrow billing adjustment can represent the durable billing decision.

## Append-Only Billing Adjustments

When a later event changes invoice interpretation of an earlier event, write an append-only adjustment instead of mutating the earlier event.

Recommended shape:

```text
original_event_id or sp_return_log_id
adjustment_type integer enum
reason integer enum
related_event_id, if applicable
created_at
```

Use integer-backed enums for durable categories. Avoid free-form strings.

Example pattern:

```ruby
enum :adjustment_type, {
  exclude_from_billing: 1,
}

enum :reason, {
  delegated_token_issued: 1,
}
```

Reports should consume generic adjustment semantics, not feature-specific internals.

## Data Sensitivity

Every new database field must match existing schema sensitivity conventions.

Before adding a column:

```text
inspect analogous tables in db/schema.rb
match sensitive=true / sensitive=false comment patterns
prefer digests/fingerprints/opaque IDs over raw sensitive values
avoid indexes on sensitive raw values unless already established and justified
confirm field names do not reveal PII or credential meaning unnecessarily
```

Sensitive values should not be persisted unless required. Cache-only storage, digests, fingerprints, or opaque identifiers are preferred.

## Analytics Events

Analytics events must never contain PII attributes.

Do not add these to analytics payloads:

```text
names
emails
phone numbers
addresses
SSNs
dates of birth
decrypted identity attributes
proofing attributes
raw credentials or tokens
raw session identifiers
```

If information is only needed for audit, troubleshooting, or operational visibility, prefer analytics/logging over a new database field, but keep analytics PII-free.

Before adding analytics data, ask:

```text
Will product logic query this later?
Will billing reports need relational lookup?
Will security controls require durable relational lookup?
Can this be a non-PII event property instead?
```

## Preserve Analytics Event Shape

Analytics events feed downstream transformations. Preserve existing keys and nesting.

Do not:

```text
rename existing keys
move existing keys to a different nesting level
change an existing scalar into an object or array
change an existing object into a scalar
remove existing keys
```

Allowed with care:

```text
append a new optional property inside an existing JSON blob
append a new enum/value to an existing populated key when downstream consumers can tolerate it
add a new optional top-level key without changing existing keys
create a new event when semantics materially differ
```

Prefer:

```text
reuse existing events when the action is the same
append optional properties rather than restructure
keep values stable and documented
coordinate new values with downstream consumers
```

## Attempts API Events

PII-relevant proofing events must use the Attempts API path and existing OpenAPI schema conventions. Attempts events are the controlled path for proofing-related event data.

If an Attempts event needs a property for delegated access, authorization-token flow, or related metadata:

```text
update the corresponding Attempts OpenAPI schema first
preserve existing event keys and nesting
minimize new event additions
prefer optional properties on the existing appropriate event when semantics match
avoid PII in the added property unless the schema and Attempts API purpose explicitly allow it
coordinate downstream schema consumers before relying on the new field
```

Do not use analytics events as a backdoor for PII that belongs in Attempts API schemas.

## Audit-Only Information

If data is only needed for audit or troubleshooting:

```text
prefer logs or analytics over database storage
avoid PII in analytics
use Attempts API for proofing-related PII event data
avoid adding durable relational state
```

Audit-only logging should still be minimized. Log the fact needed to understand the event, not the full input payload.

## Data Team Notification

Any change to database schema, durable logs, analytics events, or Attempts API event schemas must have a data team member notified or informed.

Explicit approval is not required by this guideline. Notification is required so downstream data modeling, transformations, dashboards, and reporting can account for application changes.

Notify data team members when a change:

```text
adds or removes a database column/table
changes the meaning of a persisted field
adds a durable log row type or billing adjustment reason
adds or changes analytics event properties
adds or changes Attempts API event properties or schemas
changes enum values used in reporting or analytics
changes retention, pruning, or expiration behavior for persisted data
```

## Review Checklist

Use this checklist before approving persistence-related changes:

```text
Requirement
  What exact requirement needs this data?
  Is durable persistence required, or would cache/logging suffice?

Table ownership
  Does the target table own this concept?
  Is a broad table being expanded for a narrow feature?

Log immutability
  Is any prior log row updated or reclassified?
  Should this be an append-only adjustment instead?

Cache suitability
  Is this short-lived or session-bounded state?
  Are TTL and cache-miss behavior defined?

Token state
  Does token state need to survive session/cache expiry?
  Are retention and pruning defined?

Billing grain
  Does the change preserve issuer/integration grain?
  Is resource/audience data kept out of billing identifiers?

Sensitivity
  Does the schema comment match existing sensitive=true/false patterns?
  Could the field contain PII now or later?
  Can a digest or opaque ID be used instead?

Analytics
  Is analytics payload PII-free?
  Are existing event keys and nesting preserved?

Attempts API
  Does proofing-related event data belong in Attempts API?
  Has the OpenAPI schema been updated first?

Data team
  Has a data team member been informed?

Tests
  What CI/spec fails if this write path stops working?
  What CI/spec proves cache expiry/session expiry behavior?
  What CI/spec proves reports consume the adjusted data correctly?
```

## Strong Defaults

Default to:

```text
append-only logs
narrow feature-specific tables
integer-backed enums for durable categories
TTL cache for short-lived and session-bounded state
analytics logs for audit-only non-PII observations
Attempts API schemas for proofing-related event data
no PII in analytics events
schema sensitivity comments matching existing patterns
minimal report-facing billing evidence
no broad-table expansion without explicit justification
no identifier-grain changes
explicit retention/pruning for large token tables
data team notification for database/log/event changes
```
