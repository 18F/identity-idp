# Build agency-scoped delegated identity claims

Forward the original assurance and agency identifier, restrict claims after the original session ends, and apply application sharing policy.

## Review boundary

Compare with `dcl/delegated-access/billing-evidence`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Forward the original assurance and agency identifier, restrict claims after the original session ends, and apply application sharing policy.

## Changed files

- `app/presenters/openid_connect_user_info_presenter.rb`
- `app/services/attribute_asserter.rb`
- `app/services/delegated_token_claims.rb`
- `app/services/openid_connect_claims_formatter.rb`
- `spec/services/attribute_asserter_spec.rb`
- `spec/services/delegated_token_claims_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
