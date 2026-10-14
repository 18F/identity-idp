# Verify DPoP signatures and prevent proof replay

Validate proof signatures, request method and URL, freshness, token hash and key thumbprint. Record proof identifiers atomically for replay detection.

## Review boundary

Compare with `dcl/delegated-access/registry`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Validate proof signatures, request method and URL, freshness, token hash and key thumbprint. Record proof identifiers atomically for replay detection.

## Changed files

- `app/services/dpop_proof_verifier.rb`
- `app/services/replay_guard.rb`
- `spec/services/dpop_proof_verifier_spec.rb`
- `spec/services/replay_guard_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
