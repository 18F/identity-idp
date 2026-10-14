# Release fraud signals only to approved agency recipients

Release the buffered sign-in and subsequent session events to enrolled agency recipients under approved delegation. Keep historical-release checks explicit.

## Review boundary

Compare with `dcl/delegated-access/fraud-session-buffer`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Release the buffered sign-in and subsequent session events to enrolled agency recipients under approved delegation. Keep historical-release checks explicit.

## Changed files

- `app/controllers/concerns/idv/historical_attempts_concern.rb`
- `app/services/attempts_api/delegated_release.rb`
- `app/services/attempts_api/historical_attempt_event.rb`
- `app/services/attempts_api/historical_release_check.rb`
- `spec/services/attempts_api/delegated_release_spec.rb`
- `spec/services/attempts_api/historical_release_check_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
