# Report delegated usage without changing disabled report shapes

Apply append-only invoice adjustments at issuer grain, add delegated breakdowns while enabled, and preserve the existing CSV and daily JSON shapes while disabled.

## Review boundary

Compare with `dcl/delegated-access/endpoint-wiring`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Apply append-only invoice adjustments at issuer grain, add delegated breakdowns while enabled, and preserve the existing CSV and daily JSON shapes while disabled.

## Changed files

- `app/jobs/reports/combined_invoice_supplement_report_v2.rb`
- `app/jobs/reports/daily_auths_report.rb`
- `app/jobs/reports/delegation_outcomes_report.rb`
- `app/services/db/monthly_sp_auth_count/new_unique_monthly_user_counts_by_partner.rb`
- `app/services/db/monthly_sp_auth_count/total_monthly_auth_counts.rb`
- `app/services/db/monthly_sp_auth_count/total_monthly_auth_counts_within_iaa_window.rb`
- `app/services/db/monthly_sp_auth_count/unique_monthly_auth_counts_by_iaa.rb`
- `lib/reporting/identity_verification_outcomes_report.rb`
- `spec/jobs/reports/combined_invoice_supplement_report_v2_spec.rb`
- `spec/jobs/reports/daily_auths_report_spec.rb`
- `spec/jobs/reports/delegation_outcomes_report_spec.rb`
- `spec/lib/reporting/identity_verification_outcomes_report_spec.rb`
- `spec/services/db/monthly_sp_auth_count/new_unique_monthly_user_counts_by_partner_spec.rb`
- `spec/services/db/monthly_sp_auth_count/total_monthly_auth_counts_within_iaa_window_spec.rb`
- `spec/services/db/monthly_sp_auth_count/unique_monthly_auth_counts_by_iaa_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
