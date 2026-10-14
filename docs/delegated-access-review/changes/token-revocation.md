# Revoke one token or its entire refresh family

Keep access-token revocation separate from family revocation and enforce stored key bindings even after registration changes.

## Review boundary

Compare with `dcl/delegated-access/token-introspection`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Keep access-token revocation separate from family revocation and enforce stored key bindings even after registration changes.

## Changed files

- `app/controllers/openid_connect/revoke_controller.rb`
- `app/forms/openid_connect_revoke_form.rb`
- `spec/requests/openid_connect/revoke_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
