# Document and verify delegated-access Attempts events

Publish the consent, issuance, renewal and revocation schemas and verify their payloads against the lifecycle event writer. Review agency identifiers, encryption and delivery gates separately from session buffering.

## Review boundary

Compare with `dcl/delegated-access/token-state`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Publish the consent, issuance, renewal and revocation schemas and verify their payloads against the lifecycle event writer. Review agency identifiers, encryption and delivery gates separately from session buffering.

## Changed files

- `docs/attempts-api/compiled-api.yml`
- `docs/attempts-api/schemas/AllEvents.yml`
- `docs/attempts-api/schemas/events/DelegationEvents.yml`
- `docs/attempts-api/schemas/events/delegated-access/DelegatedAccessConsented.yml`
- `docs/attempts-api/schemas/events/delegated-access/DelegatedAccessRevoked.yml`
- `docs/attempts-api/schemas/events/delegated-access/DelegatedAccessTokenIssued.yml`
- `docs/attempts-api/schemas/events/delegated-access/DelegatedAccessTokenRefreshed.yml`
- `docs/attempts-api/schemas/events/shared/EventProperties.yml`
- `spec/services/attempts_api/delegated_event_writer_spec.rb`
- `spec/services/delegated_access_events_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
