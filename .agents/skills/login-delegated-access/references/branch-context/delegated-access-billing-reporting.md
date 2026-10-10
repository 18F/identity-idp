# delegated-access-billing-reporting

## Purpose

Plan 5.8, billing and reporting. The exchange writes an `sp_return_logs` row under the API's `billing_issuer` marked `delegated`, through the one writer the direct handoff also uses; the service provider's own sign-in is waived through an append-only adjustment row (never by mutating a return log); the invoice queries exclude adjusted rows and add delegated-only breakouts; a monthly `DelegationOutcomesReport` counts approvals and sign-ins. The foundation billed the target at mint with a request id keyed to the browser session and no marker.

## Requirements it satisfies

FR-BIL-1 to FR-BIL-10. Companion §9 (BIL-1..14 as amended in §9.5, BIL-15) and *How billing works under delegated access*.

## What it adds / removes and why

Adds:
- Migrations `20261009130000_add_access_type_to_sp_return_logs` (`access_type` string, nullable, default `direct`; every report filter reads `COALESCE(access_type, 'direct')` so the table is not rewritten) and `20261009130100_create_sp_return_log_billing_adjustments` (append-only, `SpReturnLogBillingAdjustment#readonly?` once persisted; `adjustment_type` `exclude_from_billing`/`delegated_token_issued`, `resolved_via` `cache`/`database_fallback`, references to the sign-in row, the delegated row and the issuance record) (D40).
- `Billing::SpReturnLogWriter.write`: the only place a return-log row is created; `BillableEventTrackable#create_sp_return_log` calls it with the direct row's columns unchanged; the insert runs in a savepoint and `retry_on_collision: true` retries a billable collision once as a non-billable trail row.
- `Billing::SignInWaiverLink`: at the handoff to a service provider approved for delegation (`BillableEventTrackable#link_sign_in_for_delegated_billing`) the billable sign-in row's id goes to Redis keyed by `OpaqueToken.digest` of the service provider's access token for `token_exchange_billing_waiver_cache_seconds` (3600, D41); the token is never stored.
- `Billing::DelegatedReturnRecorder#call` at the end of `OpenidConnectTokenExchangeForm#issue!`, in a savepoint with every error reported and swallowed (D42): the agency's row under `billing_issuer_value`, `access_type: 'delegated'`, `ial` from `IalContext#bill_for_ial_1_or_2`, request id `tx:<delegation_id>:<billing issuer>:<ial>` (first exchange billable, later ones trail; refreshes write nothing); a `delegated_token_issued` adjustment linking the row to the issuance record (the join every report follows for the acting service provider, the API and `proofed_in_session`); for a billable row an `exclude_from_billing` adjustment on the sign-in row found by the cache or, on a miss, by database fallback (most recent billable direct row for the user and issuer with `returned_at >= identities.last_authenticated_at`). Logged as `delegated_billing_waiver(outcome: cache_hit | db_fallback | not_found, …)`.
- Invoice queries: `UniqueMonthlyAuthCountsByIaa`, `TotalMonthlyAuthCountsWithinIaaWindow` and `NewUniqueMonthlyUserCountsByPartner` exclude adjusted sign-in rows with `NOT EXISTS` (`SpReturnLogBillingAdjustment.not_excluded_sql`); delegated-only counts (`delegated_only_unique_users`, the two partner columns using `proofed_in_session_sql`) and the three trailing `CombinedInvoiceSupplementReportV2` columns; `DailyAuthsReport#results_by_access_type`; `Reporting::IdentityVerificationOutcomesReport` leaves delegated rows out. `TotalMonthlyAuthCounts` unchanged (D43).
- `Reports::DelegationOutcomesReport` (monthly, `job_configurations.rb`): per service provider, agency and API `billing_issuer_has_agreement`, `requested`, `withdrawn_before_use`, `consented_not_exchanged`, `exchanged`, `proofed_in_session_not_exchanged`; per service provider the sign-ins still billed and waived; S3 under `delegation-outcomes-report` and `delegation-sign-ins-report`, emailed to `delegation_outcomes_report_emails` (D68). Seeder and updater warn through `TokenExchangeResourceServer#warn_if_unbillable` (FR-BIL-10).

Removes:
- The foundation's `bill_target` and `billing_request_id`: the dedupe key becomes the approval and the row carries the agency's billing issuer.
- Not ported from `token-exchange2`: `sp_return_logs.identity_id`, `delegating_sign_in`, `waive_sign_in_billing` (a return log is append-only; identity is user plus issuer, not one sign-in).

## Key decisions

- D40 one marker column; service provider, API and proofing by join through the issuance record (rejected: three marker columns on `sp_return_logs`).
- D41 one-hour cache (rejected: the 12-hour session lifetime); D42 database fallback, the exchange never refused for billing (replaces "proceed and alert").
- D43 every agency that received a token in a proofed sign-in is billed for the verification; the service provider is waived.
- D68 `withdrawn_before_use` instead of a declined column; D75 the five data-team items stand as built.

## Key files

Models: `app/models/sp_return_log_billing_adjustment.rb`, `app/models/sp_return_log.rb`.
Forms: `app/forms/openid_connect_token_exchange_form.rb` (recorder call in `#issue!`).
Services: `app/services/billing/sp_return_log_writer.rb`, `app/services/billing/sign_in_waiver_link.rb`, `app/services/billing/delegated_return_recorder.rb`, `app/services/db/monthly_sp_auth_count/{unique_monthly_auth_counts_by_iaa,total_monthly_auth_counts_within_iaa_window,new_unique_monthly_user_counts_by_partner,total_monthly_auth_counts}.rb`, `app/services/service_provider_seeder.rb`, `app/services/service_provider_updater.rb`, `app/services/analytics_events.rb`.
Controllers/jobs: `app/controllers/concerns/billable_event_trackable.rb`, `app/jobs/reports/delegation_outcomes_report.rb`, `app/jobs/reports/combined_invoice_supplement_report_v2.rb`, `app/jobs/reports/daily_auths_report.rb`, `lib/reporting/identity_verification_outcomes_report.rb`.
Migrations: `20261009130000_add_access_type_to_sp_return_logs`, `20261009130100_create_sp_return_log_billing_adjustments`.
Specs: `spec/services/billing/*_spec.rb`, `spec/models/sp_return_log_billing_adjustment_spec.rb`, `spec/controllers/concerns/billable_event_trackable_spec.rb`, `spec/services/db/monthly_sp_auth_count/*_spec.rb`, `spec/jobs/reports/{delegation_outcomes_report,combined_invoice_supplement_report_v2,daily_auths_report}_spec.rb`, `spec/lib/reporting/identity_verification_outcomes_report_spec.rb`, `spec/requests/openid_connect/token_exchange_spec.rb`, the seeder and updater specs.
Config: `config/initializers/job_configurations.rb`, `lib/identity_config.rb` and `config/application.yml.default` (`token_exchange_billing_waiver_cache_seconds`, `delegation_outcomes_report_emails`).

## Commits

- `5c42ac0520` FR-BIL-1, FR-BIL-7, FR-BIL-8: mark delegated billing rows and record billing adjustments
- `34c77be874` FR-BIL-1, FR-BIL-6: write direct and delegated billing rows through one writer
- `867bd27c1b` FR-BIL-7, FR-BIL-8: link a delegating service provider's sign-in to its access token
- `54284655e2` FR-BIL-1, FR-BIL-2, FR-BIL-6, FR-BIL-7, FR-BIL-8: bill the agency at exchange and waive the sign-in
- `73217176d9` FR-BIL-3, FR-BIL-4, FR-BIL-9: count delegated rows in the invoice and operational reports
- `0c47b98dc9` FR-BIL-5, FR-BIL-8, FR-BIL-10: monthly delegation outcomes report and billing-issuer warnings
- `8bc66df799` FR-BIL-8: onboarding reads the resource server's own unbillable warning
- `5e7478240f` FR-BIL-7: the sign-in waiver link digests the access token through OpaqueToken

## How to review

Diff against `delegated-access-operations`; billing changes follow the repository skill `.claude/skills/login-billing`. Check first: `SpReturnLogWriter` is called by the direct path with exactly its former columns (the direct row must not change, BIL-5); the recorder's savepoint and error swallowing; the request id shape; the `NOT EXISTS` in the three invoice queries and that `TotalMonthlyAuthCounts` is untouched; the adjustment model's `readonly?`. Specs: the three `Billing::*` specs, the adjustment model spec, the trackable concern spec, the invoice query specs, the outcomes report spec. Must not change for existing clients: rows written before the column read as direct; a service provider not approved for delegation never writes a waiver link; the invoice totals for a partner with no delegated rows are identical.

## Known open items and later amendments

- Amended 2026-10-11 (reuse review): `warn_if_unbillable` from the registry branch; `SignInWaiverLink.digest` via `OpaqueToken.digest`.
- For the data team (D75, BIL-15): the fallback's matching rule can pick the wrong row for a person who signed in twice in the window; `not_found` leaves the service provider billed alongside an agency; `TotalMonthlyAuthCounts` and `DailyAuthsReport` keep counting waived sign-ins; the supplement's three delegated columns are subsets, not addends; the `access_type` backfill is implicit (`NULL` reads as direct).
- The branch's specs could not run at build time (shared test database held by another worktree) and were verified on the integrated stack.
- Held until the harness run (plan 6.1): a durable `identities`-to-return-log link replacing the Redis waiver link (a billing change under the `login-billing` skill).

## Depends on / depended on by

Depends on `delegated-access-token-exchange` (`#issue!`, the issuance record), the lifecycle branch (renewals write nothing), consent (approval rows for the outcomes report) and the registry (`billing_issuer`, `warn_if_unbillable`); placed after operations by D64. Depended on by `delegated-access-fraud-signals` and `delegated-access-config-content` by position.
