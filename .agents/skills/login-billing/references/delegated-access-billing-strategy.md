<!-- Vendored from the data team's docs/delegated-access-billing-strategy.md on the `token-exchange2-login`
branch (fetched 2026-10-10), quoted as written except that the real service provider's name is replaced
by "the service provider" in prose and by `service-provider.example.gov` in example issuer values (53 occurrences), because this repository names no real service
provider or agency; the source's own vocabulary ("broker") is otherwise kept. This is the design the
built billing follows; SKILL.md section 7 lists the two points where the product owner decided
differently (the 1-hour cache TTL and the database fallback on a cache miss). -->

# Delegated Access Billing Strategy

## Purpose

This note applies the data review guidance in [Data Change Review Guidelines](./data-change-review-guidelines.md) to delegated-access billing.

This note scopes the delegated-access billing design to two concerns:

1. **Fragile broker-return linking**: the current branch links a later delegated token exchange back to an the service provider return by using `identity_id` and the latest direct return row. That is too broad because an identity is user + issuer, not user + issuer + request/session.
2. **Append-only billing treatment**: `sp_return_logs` is a return log. Rows should not be mutated after they are written. Delegated token exchange should not flip an the service provider return row from billable to non-billable.

The simplified recommendation is intentionally data-minimizing:

```text
Use cache for short-lived broker-return correlation.
Use a generic append-only billing adjustment table for durable billing evidence.
Keep billing at issuer/integration grain.
Do not add delegated-access state to broad existing tables.
Do not add a durable return-context table for the first implementation.
Do not persist resource/audience/proofing metadata for billing unless it is required for a concrete billing decision.
```

## Scoped Billing Requirement

The requirement is:

```text
Bill the target when a delegated token is issued.
Do not bill the service provider for the broker return when that delegated token is issued.
Bill the service provider when no delegated token is issued.
```

The requirement is **not** to prove that the delegated exchange belongs to the exact prior State browser flow that sent the user to the service provider. The target relationship should come from token exchange `resource` and grant/scope validation, not from recent State return-log inference.

## Current Branch Risk

The current branch writes a delegated target return row, then mutates the earlier the service provider direct return row:

```ruby
row.update!(billable: false, access_type: SpReturnLog::ACCESS_TYPE_DELEGATING_SIGN_IN)
```

That mutation happens after locating the broker return with:

```ruby
SpReturnLog.where(
  identity_id: identity.id,
  access_type: SpReturnLog::ACCESS_TYPE_DIRECT,
  billable: true,
).order(returned_at: :desc).first
```

This introduces two problems:

```text
sp_return_logs is mutated after write.
identity_id + latest direct billable return is a fragile proxy for a specific broker return.
```

`identity_id` points to the user's the service provider identity connection. It does not uniquely identify one the service provider authorization request, browser return, or subject token.

## Current Implementation To Remove Or Avoid

The simplified design should remove or avoid current-branch implementation pieces that exist only to support mutable waiver behavior.

Remove or avoid:

```text
sp_return_logs.identity_id
  Do not use return-log identity linking for delegated billing. The cache key is the subject-token digest; the durable billing evidence is the adjustment row.

SpReturnLog::ACCESS_TYPE_DELEGATING_SIGN_IN
  Do not reclassify direct broker returns after the fact. the service provider returns should remain access_type = direct.

waive_sign_in_billing
  Do not update prior sp_return_logs rows. Replace with cache lookup plus billing-adjustment creation.

Any delegated-access session/context columns on sp_return_logs
  Do not add extra return-log fields for broker context in the simplified version. Keep return logs focused on return events.

sp_return_logs.actor_issuer
  Do not add broker/session metadata to return logs if it is only needed to explain delegated exchange. Put that evidence on the billing adjustment.

sp_return_logs.resource_server_identifier
  Do not add target-resource metadata to return logs if it is only needed to explain delegated exchange. Put that evidence on the billing adjustment or token-exchange record.

sp_return_logs.delegated_proofing
  Do not add proofing/session metadata to return logs. If proofing-in-broker-session matters for billing or audit, put it on the billing adjustment or token-exchange record.

Any delegated-access fields on identities
  Do not add more delegated billing state to identities. The table is already broad and mutable for current auth/session state.
```

Keep return-log writes minimal:

```text
the service provider direct return row
  issuer = service-provider.example.gov
  access_type = direct
  existing billing fields only

Target delegated return row
  issuer = resource_server.billing_issuer_value
  access_type = delegated
  existing billing fields only
```

Delegated exchange evidence belongs in:

```text
sp_return_log_billing_adjustments
token exchange token records
```

## Simplified Linking Design

### Cache Purpose

Use cache to temporarily link the the service provider subject token to the the service provider direct return row.

This keeps temporary flow state out of durable tables. We do not need to save an auth-token correlation forever if no delegated token is issued. If no delegated exchange happens, no billing adjustment is written and the service provider remains invoiceable.

### Cache Entry

Create the cache entry after the the service provider direct `sp_return_logs` row is inserted and after the the service provider subject token exists.

```text
cache key: delegated-access-broker-return:<sha256(subject_token)>
cache value:
  broker_sp_return_log_id
  broker_issuer
  user_id
  request_id
  created_at
```

Example flow:

```text
the service provider broker return
  -> insert sp_return_logs A1
  -> cache sha256(subject_token) => A1.id

the service provider delegated token exchange
  -> receive subject_token
  -> lookup cache by sha256(subject_token)
  -> resolve broker_sp_return_log_id = A1.id
  -> write delegated target return D1
  -> write billing adjustment excluding A1
```

### Delegation Window

Using cache creates an explicit delegation window. the service provider does not need to exchange at the exact same instant, but it must exchange before the cache TTL expires if it expects the broker return to be excluded from billing.

That is acceptable if the product pattern is:

```text
the service provider receives auth code/access token.
the service provider promptly performs delegated token exchange.
```

The TTL should be explicit and product-approved. It should be long enough for normal the service provider processing and retries, but short enough to avoid linking stale broker returns to unrelated later exchanges. A reasonable starting point is to align the TTL with the effective subject-token/session lifetime used by token exchange.

### Cache Miss Behavior

Cache miss behavior must be explicit.

Recommended default:

```text
Allow token exchange if token exchange validation succeeds.
Write the delegated target return.
Do not write a broker billing adjustment.
the service provider remains invoiceable.
Log and alert the cache miss.
```

This avoids blocking token exchange because of billing-correlation cache loss. The tradeoff is that cache loss can overbill the service provider. If that tradeoff is unacceptable, a durable context table may be needed later, but that is out of scope for the simplified first implementation.

Avoid falling back to "latest the service provider return for identity" unless explicitly accepted, because that reintroduces the fragile linking concern.

## Target Relationship

Do not infer the delegated target from the most recent State return. A user can have multiple State flows at once, including IAL1 and IAL2 flows.

The current branch already models the delegated target explicitly:

```text
token_exchange_scopes.resource_server_id
  -> token_exchange_resource_servers.id
  -> token_exchange_resource_servers.service_provider_id
  -> service_providers.issuer for the target agency
```

At exchange time:

```text
request resource
  -> TokenExchangeResourceServer
  -> grants whose scopes belong to that resource server
  -> resource_server.billing_issuer_value
```

That explicit resource/scope/grant relationship should determine the delegated target and billing issuer.

## Data Minimization Recommendations

Strong recommendations:

```text
Do not modify issuer values to encode resource/audience information.
Do not persist resource/audience information in sp_return_logs for billing.
Do not persist resource/audience information in billing adjustments for the scoped billing requirement.
Do not persist delegated proofing/session metadata in sp_return_logs.
Do not persist delegated proofing/session metadata in billing adjustments unless it becomes required for a concrete billing decision.
```

Billing should remain at issuer/integration grain:

```text
broker_issuer = service-provider.example.gov
target_issuer = State billing issuer
```

If token exchange requires resource/audience data for token issuance, introspection, refresh, or revocation, keep that data in token-exchange-specific records or configuration. If resource/audience data is only useful for troubleshooting, capture it in logs or analytics rather than billing database tables.

`token_exchange_tokens` may grow quickly and contains operational token lifecycle data. If delegated access is bounded to the user's normal AAL/session timeout, durable token persistence should be reviewed separately and skeptically: cache/session-bound storage may be sufficient, and users should re-authenticate to authorize delegation after session expiry. If the table remains, it needs explicit retention, pruning, indexing, row-growth analysis, and field-by-field justification. It should not drive extra billing-schema persistence.

## Billing Adjustment Table

### Table Purpose

Use a generic append-only table to record durable billing decisions. The adjustment table is the durable evidence that the service provider's broker return should be excluded because a delegated token was issued.

Adjustment categories should be integer-backed Rails enums, similar to `Profile.idv_level`, not free-form strings. That keeps valid values constrained in code and makes unintended future uses visible in review.

This lets invoice reports use a generic exclusion rule instead of embedding token-exchange-specific logic in every report.

### Proposed Table

```text
sp_return_log_billing_adjustments
  id
  sp_return_log_id
  adjustment_type integer, null: false
  reason integer, null: false
  related_sp_return_log_id
  token_exchange_token_id
  broker_subject_token_digest
  broker_issuer
  target_issuer
  request_id
  effective_at
  created_at
```

Initial enum values:

```ruby
enum :adjustment_type, {
  exclude_from_billing: 1,
}

enum :reason, {
  delegated_token_issued: 1,
}
```

Column meaning:

```text
sp_return_log_id
  The return row being adjusted, e.g. the service provider direct return.

adjustment_type
  Integer-backed enum for the adjustment action. Initial value: exclude_from_billing = 1.

reason
  Integer-backed enum for the specific adjustment reason. Initial value: delegated_token_issued = 1.

related_sp_return_log_id
  The delegated target return row that caused the adjustment.

token_exchange_token_id
  The delegated token that caused the adjustment.

broker_subject_token_digest
  Digest of the the service provider subject token used to resolve the cache entry.

broker_issuer
  The broker issuer, e.g. service-provider.example.gov.

target_issuer
  The delegated target billing issuer.
```

Sample row:

```text
sp_return_log_id = the service provider direct return A1
adjustment_type = 1 # exclude_from_billing
reason = 1 # delegated_token_issued
related_sp_return_log_id = State delegated return D1
token_exchange_token_id = T1
broker_subject_token_digest = sha256(the service provider subject token)
broker_issuer = service-provider.example.gov
target_issuer = State billing issuer
```

### Reporting Rule

Invoice reports should use a generic exclusion filter:

```sql
WHERE sp_return_logs.billable = true
  AND NOT EXISTS (
    SELECT 1
    FROM sp_return_log_billing_adjustments adjustments
    WHERE adjustments.sp_return_log_id = sp_return_logs.id
      AND adjustments.adjustment_type = 1 -- exclude_from_billing
  )
```

Rails code should use enum names (`exclude_from_billing`, `delegated_token_issued`) rather than hard-coded integers. Raw SQL report code should keep comments next to enum integers, or centralize the value in a report helper/constant to avoid magic numbers.

This keeps token exchange semantics out of report queries. Token exchange creates the adjustment; reports consume invoiceable rows.

## Return Counts

In the State-first happy path:

```text
State direct Login.gov return
  -> one State direct sp_return_logs row

the service provider broker Login.gov return
  -> one the service provider direct sp_return_logs row
  -> one cache entry for the the service provider subject token

the service provider normal auth-code token redemption
  -> no sp_return_logs row

the service provider delegated token exchange for State
  -> one State delegated sp_return_logs row
  -> one billing adjustment excluding the the service provider direct row
```

Token refreshes should not write return rows.

For multiple delegated targets from one the service provider auth token:

```text
one the service provider direct return row
one temporary cache entry during the delegation window
one delegated target return row per delegated exchange/billing event
one billing adjustment row per delegated exchange/billing event
```

Invoice reports should exclude the the service provider broker return with `EXISTS`, so the service provider is excluded once even if multiple adjustment rows reference the same broker return.

## High Fan-Out

If one the service provider auth token produces many delegated exchanges, the cache entry remains one entry keyed by subject-token digest. Each delegated exchange during the cache window can reuse the same `broker_sp_return_log_id`.

Example for 25,000 delegated exchanges:

```text
1 temporary cache entry
25,000 delegated token rows
25,000 delegated sp_return_logs rows, if each exchange is a real delegated return/billing event
25,000 billing adjustment rows, or one broker exclusion plus detail rows if optimized later
```

The first implementation should prefer traceability and clear tests over optimizing for unlikely high fan-out. If high fan-out becomes practical, split the model later into:

```text
one broker exclusion adjustment
many delegated exchange detail rows
```

## Test And CI Guardrails

The primary risk is silent drift: token exchange behavior could change upstream and stop creating the expected return rows or billing adjustments.

Recommended guardrails:

1. Immutability tests
   - Successful delegated token exchange must not update the original the service provider `sp_return_logs` row.
   - The the service provider return log row must remain `access_type = direct` and preserve its original `billable` value.

2. Cache-linking tests
   - the service provider broker return creates a cache entry keyed by subject-token digest.
   - Delegated token exchange resolves the broker return from the cache entry.
   - One the service provider subject token can produce multiple delegated exchanges within the cache window.
   - Cache miss behavior is explicit and tested.

3. Billing adjustment tests
   - Successful delegated token exchange appends an adjustment with `adjustment_type = exclude_from_billing` and `reason = delegated_token_issued`.
   - Failed token exchange does not create delegated return rows or billing adjustments.
   - Normal auth-code redemption does not create delegated return rows or billing adjustments.
   - Refresh token use does not create delegated return rows or billing adjustments.
   - Unsupported adjustment enum values are rejected by model validations and database constraints where practical.
   - Delegated-token adjustments require a broker return row, related delegated return row, and token exchange token.

4. Invoice report regression tests
   - the service provider remains invoiceable when no delegated token is issued.
   - the service provider is excluded when at least one delegated token is issued and an adjustment exists.
   - State delegated rows remain invoiceable.
   - Multiple delegated adjustment rows for one broker return exclude the service provider once.
   - State direct and delegated rows collapse under existing unique-user/month aggregation when they map to the same user/month/order.

5. Full-path integration test
   - the service provider return through delegated token exchange should assert cache entry creation, delegated return row creation, and billing adjustment creation.
   - This test should fail CI if upstream token exchange changes stop creating the expected cache linkage, delegated return rows, or adjustments.

## Branching Plan

Build from the current `token-exchange2-login` branch, split into two local branches, then replay or recreate them in the correct GitHub location after the current token exchange branch moves there.

### Branch 1: Short-Lived Broker Return Linking

Purpose:

```text
Create a cache-backed link from the service provider's subject token to the the service provider direct return row.
```

Scope:

```text
write cache entry after the service provider direct return is logged
key cache entry by digest of the service provider subject token
resolve cache entry during delegated token exchange
carry broker_sp_return_log_id into token exchange billing-adjustment creation
add cache hit, cache miss, and multi-delegation tests
```

Do not change invoice semantics in this branch except where needed to keep existing tests passing.

### Branch 2: Append-Only Billing Adjustments

Purpose:

```text
Replace mutable broker-waiver behavior with generic billing adjustments.
```

Scope:

```text
create sp_return_log_billing_adjustments
remove code that mutates sp_return_logs for delegation billing
write exclude_from_billing/delegated_token_issued adjustment on successful delegated exchange when cache link exists
update invoice report queries to exclude adjusted rows
update delegation outcomes report to count adjustments rather than mutated access_type
add invoice/report regression tests
```

## Recommendation

Proceed with the simplified two-branch plan:

1. Add cache-backed broker-return linking.
2. Add generic append-only billing adjustments and update reporting.

Minimum acceptable end state:

```text
sp_return_logs are never mutated for delegated billing.
the service provider direct returns are excluded from invoicing, even if billable = true, only when a delegated token was issued and an adjustment exists.
Delegated target returns remain invoiceable under target issuers.
No delegated-access state is added to broad existing tables like identities.
A full-path test fails CI if token exchange stops creating the expected cache linkage, delegated return rows, and adjustment rows.
```
