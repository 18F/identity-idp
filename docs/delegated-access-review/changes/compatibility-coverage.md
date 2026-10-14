# Verify disabled features and rollback across the complete flow

Add release-blocking regressions for legacy input acceptance, saved key bindings, refresh/revocation races, allowlist removal and immutable authentication time, alongside the threat scenarios.

## Review boundary

Compare with `dcl/delegated-access/encrypted-userinfo`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Add release-blocking regressions for legacy input acceptance, saved key bindings, refresh/revocation races, allowlist removal and immutable authentication time, alongside the threat scenarios.

## Changed files

- `spec/controllers/users/rules_of_use_controller_spec.rb`
- `spec/features/openid_connect/openid_connect_spec.rb`
- `spec/requests/openid_connect/delegated_access_compatibility_spec.rb`
- `spec/requests/openid_connect/delegated_access_threats_spec.rb`
- `spec/requests/openid_connect/saml_assertion_exchange_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
