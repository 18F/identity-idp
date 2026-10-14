# Record delegated billing as append-only evidence

Share the return-row writer, link sign-ins by token digest, and record invoice adjustments without rewriting prior billable events. Disabled direct sign-ins retain their previous stored values.

## Review boundary

Compare with `dcl/delegated-access/fraud-consent-release`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Share the return-row writer, link sign-ins by token digest, and record invoice adjustments without rewriting prior billable events. Disabled direct sign-ins retain their previous stored values.

## Changed files

- `app/controllers/concerns/billable_event_trackable.rb`
- `app/models/sp_return_log.rb`
- `app/models/sp_return_log_billing_adjustment.rb`
- `app/services/billing/delegated_return_recorder.rb`
- `app/services/billing/sign_in_waiver_link.rb`
- `app/services/billing/sp_return_log_writer.rb`
- `spec/controllers/concerns/billable_event_trackable_spec.rb`
- `spec/models/sp_return_log_billing_adjustment_spec.rb`
- `spec/services/billing/delegated_return_recorder_spec.rb`
- `spec/services/billing/sign_in_waiver_link_spec.rb`
- `spec/services/billing/sp_return_log_writer_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
