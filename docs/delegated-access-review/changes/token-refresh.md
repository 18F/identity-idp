# Rotate refresh tokens without weakening family security

Rotate under a row lock, detect reuse, enforce family expiry and continuing approval, and preserve existing unbound families when client settings change.

## Review boundary

Compare with `dcl/delegated-access/token-exchange`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Rotate under a row lock, detect reuse, enforce family expiry and continuing approval, and preserve existing unbound families when client settings change.

## Changed files

- `app/controllers/openid_connect/token_controller.rb`
- `app/forms/openid_connect_refresh_token_form.rb`
- `spec/requests/openid_connect/token_refresh_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
