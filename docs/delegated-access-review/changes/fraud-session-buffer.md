# Buffer delegated-session fraud signals securely

Keep pending sign-in events in the encrypted session, bound the buffer, and preserve direct Attempts delivery.

## Review boundary

Compare with `dcl/delegated-access/fraud-event-catalog`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Keep pending sign-in events in the encrypted session, bound the buffer, and preserve direct Attempts delivery.

## Changed files

- `app/services/attempts_api/attempt_event.rb`
- `app/services/attempts_api/delegation_context.rb`
- `app/services/attempts_api/tracker.rb`
- `lib/session_encryptor.rb`
- `spec/services/attempts_api/delegation_context_spec.rb`
- `spec/services/attempts_api/tracker_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
