---
name: login-billing
description: Use for any change to Login.gov delegated-access billing, sp_return_logs, invoices, billing reports, the delegation outcomes report, or the service-provider sign-in waiver.
---

# Login.gov billing under delegated access

## 1. When to use

Load this skill before touching anything that writes or reads `sp_return_logs` or
`sp_return_log_billing_adjustments`, the invoice aggregates and supplement, the daily or IdV
outcomes reports, the delegation outcomes report, the delegated row written at token exchange, or
the service-provider sign-in waiver. It describes billing as built on
`delegated-access-billing-reporting` under the product owner's decisions (plan D40–D43, D68,
D75), which override the documents in section 7.

Terminology: "service provider" (never "broker"); "application" for the agency's record; "resource
server" or "agency API". Fictitious names only in examples: MyBenefits Assistant (service provider);
Department of Housing Support / Housing Assistance Records; National Retirement Administration /
Retirement Benefits Portal.

## 2. Rules (checklist)

Product-owner decisions, 2026-10-09. Where a source document disagrees, these win.

- [ ] `sp_return_logs` is append-only. Never `update!` a return-log row for billing. Billing
      changes are expressed as new rows elsewhere.
- [ ] Exactly one new column on `sp_return_logs`: `access_type` (`direct` / `delegated`,
      nullable, default `direct`; filter with `COALESCE(access_type, 'direct')`). Do not add
      `actor_issuer`, `resource_server_identifier`, `delegated_proofing`, `identity_id` or any
      session/context columns to the return log.
- [ ] The acting service provider, the resource server (API) and proofing-in-session live on the
      token issuance record (`token_exchange_tokens`, which already references service provider,
      resource server and grant). Reports that need them join to it; they do not read them from
      `sp_return_logs`.
- [ ] Delegated row: written at the exchange that mints the delegated token, under the resource
      server's `billing_issuer`, with `access_type = 'delegated'`, IAL derived from the sign-in
      (2 when the user is verified and the service provider asserted IAL2 or IALmax, else 1;
      never the raw stored `ial`), profile columns as for a direct row, and
      `request_id = "tx:<delegation_id>:<billing issuer>:<ial>"`. The unique index makes the
      first exchange per approval billable; a collision is retried with a random `request_id`
      and `billable: false` (trail row), inside a savepoint so the exchange transaction survives.
- [ ] Renewals (refresh) write nothing. Normal auth-code redemption writes nothing.
- [ ] Direct and delegated rows share one writer (`Billing::SpReturnLogWriter`) so the two shapes
      cannot drift.
- [ ] Service-provider sign-in waiver (FR-BIL-8): at the service provider's handoff write a cache
      entry keyed by the SHA-256 digest of its access token (the later subject token), value = the
      id of the sign-in's return-log row. TTL is **1 hour**. At exchange, resolve the entry and
      append one `sp_return_log_billing_adjustments` row (`exclude_from_billing` /
      `delegated_token_issued`, integer enums) pointing at the sign-in row, the delegated row and
      the token. Invoice queries exclude adjusted rows with `NOT EXISTS`.
- [ ] Cache miss at exchange: fall back to a database lookup of the service provider's return-log
      row for that user **and that sign-in** (not merely the latest row for the identity), and
      write the adjustment. This fallback must be documented for review by the data team
      (section 6). The exchange itself never fails because of billing correlation. As built,
      `Billing::DelegatedReturnRecorder` matches the service provider's most recent billable direct
      row for the user with `returned_at >= identities.last_authenticated_at` and records
      `resolved_via` (`cache` / `database_fallback`); the match rule is open item 1 in section 6.
- [ ] Proofing cost attribution: when a person verifies identity during a delegated sign-in, the
      proofing is attributed to **each agency that receives a delegated token** (every approved
      agency issued a token is billed, including proofing), **not** to the service provider.
      `profiles.initiating_service_provider_issuer` and `profile_requested_issuer` are still
      recorded unchanged (FR-BIL-6); the attribution is a reporting rule in the invoice
      supplement. The outcomes report shows `proofed_in_session` per approval (as built the column is
      `proofed_in_session_not_exchanged`, D68).
- [ ] A person is billed to an agency once per month regardless of path: `GROUP BY user_id`
      collapses direct and delegated rows. Nothing at runtime dedupes across the two paths.
- [ ] Billing never stores token values (FR-BIL-7): digests only.
- [ ] Every consumer of `sp_return_logs` is reviewed when the row shape changes (section 3 list).

## 3. How billing works today

Code (repo-relative):

| Concern | Path |
|---|---|
| One row writer | `app/services/billing/sp_return_log_writer.rb` |
| Direct handoff | `app/controllers/concerns/billable_event_trackable.rb` (`#track_billing_events`, `#create_sp_return_log`, `#link_sign_in_for_delegated_billing`); callers `app/controllers/openid_connect/authorization_controller.rb`, `app/controllers/saml_idp_controller.rb` |
| Waiver link (Redis) | `app/services/billing/sign_in_waiver_link.rb` |
| Delegated row and waiver at exchange | `app/services/billing/delegated_return_recorder.rb`, called from `OpenidConnectTokenExchangeForm#issue!` (`app/forms/openid_connect_token_exchange_form.rb`) |
| IAL billed | `app/services/ial_context.rb#bill_for_ial_1_or_2` |
| Models | `app/models/sp_return_log.rb` (`ACCESS_TYPE_DIRECT`/`ACCESS_TYPE_DELEGATED`, `has_many :billing_adjustments`, `#excluded_from_billing?`); `app/models/sp_return_log_billing_adjustment.rb` (`.not_excluded_sql`, `.proofed_in_session_sql`); `app/models/token_exchange_resource_server.rb` (`#billing_issuer_value`, `#billing_issuer_has_agreement?`, `#warn_if_unbillable`) |
| Schema | `db/schema.rb` `create_table "sp_return_logs"`, `create_table "sp_return_log_billing_adjustments"`; migrations `20261009130000_add_access_type_to_sp_return_logs`, `20261009130100_create_sp_return_log_billing_adjustments` |
| Issuer to agreement chain | `app/services/iaa_reporting_helper.rb` |
| Invoice queries | `app/services/db/monthly_sp_auth_count/unique_monthly_auth_counts_by_iaa.rb`, `new_unique_monthly_user_counts_by_partner.rb`, `total_monthly_auth_counts.rb`, `total_monthly_auth_counts_within_iaa_window.rb` |
| Reports | `app/jobs/reports/combined_invoice_supplement_report_v2.rb`, `daily_auths_report.rb`, `delegation_outcomes_report.rb` (scheduled as `delegation_outcomes_report` in `config/initializers/job_configurations.rb`); `lib/reporting/identity_verification_outcomes_report.rb` |
| Analytics event | `app/services/analytics_events.rb#delegated_billing_waiver` |
| Configuration | `token_exchange_billing_waiver_cache_seconds`, `delegation_outcomes_report_emails` in `lib/identity_config.rb` and `config/application.yml.default` |
| Index rebuild task | `lib/tasks/db_sp_return_logs_index.rake` (`db:rebuild_sp_return_logs_index`; unchanged by delegated access) |

Row shape (`sp_return_logs`): `request_id` (unique index), `user_id`, `issuer`, `ial` (1 or 2),
`billable`, `returned_at`, `profile_id`, `profile_verified_at`, `profile_requested_issuer`,
`access_type`. The profile columns are set only when the billed IAL is 2. Partial index on
`(returned_at::date, issuer) WHERE billable = true AND returned_at IS NOT NULL`.

When a row is written: at the handoff back to the service provider (authorization code or SAML
assertion) and at the token exchange that mints a delegated token; never at redemption or refresh.

Billable rule (direct): within one browser session the first handoff to an issuer at a given IAL
class is `billable: true`; the session flag `auth_counted_<issuer>` (IAL2) or
`auth_counted_<issuer>ial1` remembers it, and later handoffs write `billable: false`. In practice
the later rows usually reuse the same `request_id` and are dropped by the writer's
`rescue ActiveRecord::RecordNotUnique`. For a service provider approved for delegation the
billable row's id is kept in the user session (`delegated_billing_return_log_<issuer>`) so a
repeat handoff in the same session still points the waiver link at the invoiced row. Dedupe key:
`request_id`; the unique index is the only hard guarantee, the session flag is soft.

Who gets invoiced: a row is invoiced only if its `issuer` resolves through `integrations.issuer ->
integration_usages -> iaa_orders -> iaa_gtcs -> partner_accounts -> agencies` to an agreement in
period (`TotalMonthlyAuthCounts` also inner-joins `service_providers`). An issuer not wired in
(a `billing_issuer` without an agreement) produces rows that are recorded and never invoiced.

Monthly grouping:
- `UniqueMonthlyAuthCountsByIaa`: billable, not-excluded rows for the agreement's issuers, one
  query per month, `GROUP BY user_id, ial`. A person counts once per agreement per month however
  many rows or issuers. `new_unique_users` = users not seen earlier in the agreement period.
- `NewUniqueMonthlyUserCountsByPartner`: IAL2 billable, not-excluded rows per partner, bucketed
  by profile age; first-year events split into *upfront* and *existing*. The per-user key is
  `UserVerifiedKey(user_id, profile_id, profile_age, is_upfront)`; `DelegationFacts` is tallied
  alongside it (section 4).
- `CombinedInvoiceSupplementReportV2` assembles both. `DailyAuthsReport` and
  `TotalMonthlyAuthCounts` are operational views of the same rows (no exclusion).

Effect to preserve: a person with an existing IAL2 account at an agency who signs in again is one
unique user for the month and an existing profile; no new proofing charge.

## 4. Delegated-access additions

Two row kinds, one writer:

| | Direct sign-in | Delegated exchange |
|---|---|---|
| Written | at handoff | when the exchange mints the delegated token |
| `issuer` | the service provider signed in to | `token_exchange_resource_servers.billing_issuer`, else the issuer of the agency application that owns the API (`#billing_issuer_value`) |
| Billable once per | session, issuer, IAL | approval (`delegation_id`), billing issuer, IAL |
| `request_id` | request id of the authorization | `tx:<delegation_id>:<billing issuer>:<ial>` |
| `access_type` | `direct` | `delegated` |
| Renewals | n/a | nothing |

Schema as built (`sp_return_logs.access_type` is in section 3):

```text
sp_return_log_billing_adjustments (append-only)
  sp_return_log_id          -> the row the fact is about (null: false): the sign-in row for an
                               exclusion, the delegated row for a delegated_token_issued link
  adjustment_type           integer enum, null: false  { exclude_from_billing: 1, delegated_token_issued: 2 }
  delegated_return_log_id   -> the delegated row that caused an exclusion
  token_exchange_token_id   -> the issuance record (the join to service provider, API, grant)
  resolved_via              integer enum { cache: 1, database_fallback: 2 }  -- exclusions only
  created_at
  indexes: (sp_return_log_id, adjustment_type), delegated_return_log_id, token_exchange_token_id

Redis entry (REDIS_POOL, TTL token_exchange_billing_waiver_cache_seconds = 3600)
  key:   delegated-access-sign-in-return:<hex sha256(access token)>
  value: the sign-in's billable sp_return_logs.id
```

Invoice exclusion (`.not_excluded_sql`), applied in `UniqueMonthlyAuthCountsByIaa`,
`TotalMonthlyAuthCountsWithinIaaWindow` and `NewUniqueMonthlyUserCountsByPartner`, not in
`TotalMonthlyAuthCounts` or `DailyAuthsReport`: `billable = true AND NOT EXISTS (SELECT 1 FROM
sp_return_log_billing_adjustments a WHERE a.sp_return_log_id = sp_return_logs.id AND
a.adjustment_type = 1)`. `EXISTS` excludes the sign-in once even when several agencies' exchanges
each wrote an adjustment.

Who pays, by case (MyBenefits Assistant is the service provider). Sign-in, approvals, one or more
exchanges: each agency that received a token, once per agency per month, proofing included if the
person was proofed in that sign-in; MyBenefits Assistant's sign-in is excluded by the adjustment.
Sign-in, approvals, never exchanged: MyBenefits Assistant (it must hold a partner agreement to be
invoiced; an onboarding step). Consent screen cancelled: no approval, no row, nobody billed;
proofing cost is Login.gov's. Two APIs of one agency, or a direct sign-in to that agency in the
same month: two rows under one issuer, one billed user, not new.

Report changes:
- `UniqueMonthlyAuthCountsByIaa`, `TotalMonthlyAuthCountsWithinIaaWindow`: outputs unchanged in
  shape; delegated rows included; waived sign-ins excluded. `UniqueMonthlyAuthCountsByIaa` adds
  `delegated_only_unique_users` per IAL and month (`BOOL_AND` over the user's rows).
  `TotalMonthlyAuthCounts` is unchanged (waived sign-ins still counted).
- `NewUniqueMonthlyUserCountsByPartner`: the per-user key stays; `access_type` and
  `delegated_proofing` (by join, `.proofed_in_session_sql`) are grouped and tallied alongside,
  never part of the key. Adds `partner_ial2_unique_user_events_delegated_only` and
  `partner_ial2_unique_user_events_delegated_proofing`. A first-year event is *upfront* when
  `profile_requested_issuer == issuer` or the row has delegated proofing, so a person proofed at
  the service provider is upfront for each agency billed.
- Invoice supplement: three trailing columns, each a subset of a count to its left, never an
  addition: `iaa_ial2_delegated_only_unique_users`,
  `partner_ial2_unique_user_events_delegated_only`,
  `partner_ial2_unique_user_events_delegated_proofing`.
- `DailyAuthsReport`: `results` unchanged plus a separate `results_by_access_type` array.
- IdV outcomes report: excludes `access_type = 'delegated'` rows so an agency's proofing outcomes
  are not inflated by people proofed at the service provider.
- `Reports::DelegationOutcomesReport` (monthly over the previous month): per service provider
  issuer, agency and API over `token_exchange_grants`, superseded approvals left out:
  `billing_issuer_has_agreement`, `requested`, `withdrawn_before_use` (revoked by the person,
  reason `user_revoked`, before any exchange), `consented_not_exchanged`, `exchanged`,
  `proofed_in_session_not_exchanged`; no `declined` column (D68), a cancelled consent screen
  writes no row. Second CSV, per service provider: sign-ins billed and sign-ins waived (counted
  from adjustments). "Authorization ended" = revoked, `remember_until` passed, or a non-remembered
  grant whose `rails_session_id` no longer matches the identity's. Saved to S3 as
  `<env>/delegation-outcomes-report/<year>/<YYYY-MM>.delegation-outcomes-report.csv` and
  `<env>/delegation-sign-ins-report/<year>/<YYYY-MM>.delegation-sign-ins-report.csv`, emailed to
  `delegation_outcomes_report_emails` (json, default `[]`) when set.
- `ServiceProviderSeeder` / `ServiceProviderUpdater` call
  `TokenExchangeResourceServer#warn_if_unbillable` when an API's billing issuer is not an
  `integrations.issuer`.

## 5. Pitfalls the reviewer called out

- An identity is user + issuer, not user + issuer + sign-in. `sp_return_logs.identity_id` and
  "most recent billable direct row for this identity" cannot identify one sign-in. The waiver
  link is the subject-token digest; the fallback (section 6) must be scoped to the sign-in.
- Never mutate a return log. The earlier `waive_sign_in_billing` / `delegating_sign_in` design
  flipped `billable` after the fact and is withdrawn.
- Dedupe delegated rows by approval (`delegation_id`), not by browser session. The current
  worktree's `bill_application` / `billing_request_id` in
  `app/forms/openid_connect_token_exchange_form.rb` keys on `rails_session_id` and bills
  `application.issuer`; both are to be replaced (replaced as built by
  `Billing::DelegatedReturnRecorder`, keyed by `delegation_id`; the rule stands).
- Do not infer the target from the most recent agency sign-in; it comes from the exchange's
  `resource` -> resource server -> grants/scopes -> `billing_issuer`.
- Session flags cannot be used at exchange; it runs outside the browser session.
- A person is never counted twice for one agency in a month, and never treated as new when they
  arrive by delegation after a direct sign-in. Keep path facts out of the per-user key.
- The delegated billable row must be written inside `transaction(requires_new: true)`; a unique
  collision without a savepoint aborts the exchange transaction.
- Do not encode resource/audience into `issuer`; keep billing at issuer/integration grain.
- A `billing_issuer` not wired into an agreement records rows that are never invoiced.
- Direct-path specs assert exact row shapes; add columns, do not reshape existing output.

## 6. Open items for the data team

1. Cache-miss fallback. Document the database lookup (user + sign-in, scoped how; which row is
   chosen; what is logged) and record `resolved_via` on the adjustment so fallback use is
   measurable. The reviewer's original recommendation was no adjustment on miss; the decision to
   fall back needs their review.
2. Proofing attribution mechanics. Confirm how the invoice supplement classifies a delegated row
   as upfront for each agency when `profile_requested_issuer` is the service provider, and how
   the service provider's own agreement is kept clear of that proofing charge.
3. Lapsed agreement for an agency API: delegated rows are recorded and not invoiced; confirm
   whether the outcomes report flag is sufficient.
4. Whether the service provider pays anything for delegated use beyond its unwaived sign-ins
   (functional requirements §9 question 4), and who onboards its partner agreement.
5. Recipients of the delegation outcomes report, and whether agencies and the service provider
   see it.

Status as built (2026-10-10, D75: handed to the data team as built; nothing changes ahead of their answer):
item 1 is built as the fallback described in section 2 with `resolved_via` recorded, and the match rule
itself is what needs their review; item 2 is built by classifying upfront proofing through
`token_exchange_grants.proofed_in_session` reached from the `delegated_token_issued` adjustment
(`UserVerifiedKey` / `DelegationFacts` in the monthly counts) with `access_type` keeping the service
provider's agreement clear of it, and needs confirmation; item 3 is flagged by
`TokenExchangeResourceServer#billing_issuer_has_agreement?` and the report column
`billing_issuer_has_agreement`, sufficiency open; item 4 is open (functional requirements §9 question 4);
item 5 is configured by `delegation_outcomes_report_emails`, audience open.

Also handed over as built (plan 5.8 item 10):
6. Fallback matching rule: a person who signed in to the service provider more than once in the window
   can be matched to the wrong row; a row written before the identity was re-linked is not found.
7. `not_found` outcome: the service provider stays billed for a sign-in an agency was also billed for;
   the `delegated_billing_waiver` event counts it.
8. `TotalMonthlyAuthCounts` and `DailyAuthsReport` keep counting waived sign-ins, so they do not
   reconcile with the invoice queries for a delegating service provider.
9. The invoice supplement's three delegated columns are subsets of counts to their left and must not
   be added to them.
10. The `access_type` backfill is implicit (`NULL` reads as `direct`); a downstream extract that reads
    the column raw must apply the same `COALESCE`.

## 7. Sources and what they superseded

- *How billing works under delegated access* (2026-10-08 note): mutation waiver (`identity_id`, `delegating_sign_in`), three extra marker columns, proofing left open; superseded by section 2.
- `docs/delegated-access-billing-strategy.md` (`token-exchange2-login`, not ported): the cache +
  adjustment design adopted here; "no adjustment on cache miss" and "TTL aligned to session
  lifetime" superseded by the database fallback (D42) and the 1-hour TTL (D41).
- `docs/delegated-access-requirements.md` §9: BIL-4 (four columns, then a `token_exchange_token_id`
  column) and BIL-13 (mutation waiver; Redis key `delegation_waiver:`; `reason`/`effect` pair)
  superseded by §9.5 as amended 2026-10-10; `delegation_waiver_unresolved` is the `not_found`
  outcome of `delegated_billing_waiver`, not a separate event (BIL-15 as amended).
- `docs/delegated-access-implementation-plan.md` §5.8: the 12-hour TTL (D41) and the `declined`
  outcomes column (D68) superseded; `bill_application` / `billing_request_id` in the exchange form
  (session-keyed, billed `application.issuer`) replaced by `Billing::DelegatedReturnRecorder`.
- The pre-build draft of this skill (2026-10-09): adjustment columns `reason`, `related_sp_return_log_id`,
  `subject_token_digest`, `service_provider_issuer`, `target_issuer`, `request_id`, `effective_at`
  and a `Rails.cache` hash value; superseded by section 4.
- `docs/delegated-access-functional-requirements.md` §9: FR-BIL-1's "naming the acting service
  provider and API" is met by the join to the token record (D40).

## 8. Where this sits

The billing code lives on branch `delegated-access-billing-reporting` (plan 5.8). The
delegated-access skill at `.claude/skills/login-delegated-access` holds the branch context,
decisions and RFC digests and points here for billing changes. A change to a billing rule is
recorded as a decision in the plan (D-number) and in companion §9, following that skill's
update protocol, in the same unit of work as the code.

## 9. Data-change review (the data team's guidelines)

Any change on these branches that adds or changes a table or column, a durable log row, token
storage, billing or reporting evidence, an analytics event or an Attempts API schema is reviewed
against the data team's guidelines, vendored verbatim in
`references/data-change-review-guidelines.md`, with the billing application of them in
`references/delegated-access-billing-strategy.md`. The parts to apply every time:

- Priority order: protect PII; preserve immutable logs; keep billing and reporting grain stable;
  minimize durable persistence; preserve analytics and Attempts event shape; notify the data team.
- Decision procedure: name the exact requirement that needs the data; prefer TTL cache or
  session-bound storage for short-lived state, analytics for audit-only facts, an append-only
  adjustment for a later billing interpretation, a narrow purpose-built table for a new entity;
  expand a broad table (`users`, `identities`, `service_providers`, `sp_return_logs`, `profiles`)
  only as a last resort.
- Token state: durable token tables are disfavored when access is bounded to the session; if one
  stays, it needs a retention period tied to the token lifetime, a pruning job or partition expiry,
  indexes for the hot and pruning paths, a row-growth estimate at peak, field-by-field justification,
  digests only, and specs proving expired or revoked tokens cannot be used. (This is the open
  capacity item for `token_exchange_tokens` and `token_exchange_refresh_tokens`.)
- Data team notification is required, not approval, for any schema, durable-log, analytics or
  Attempts schema change, so downstream models and dashboards can follow.
- Review output: summary, decision, findings, persistence assessment, sensitivity assessment,
  analytics and Attempts assessment, data team notification, required tests or guardrails.
