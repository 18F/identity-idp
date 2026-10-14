# Verify delegated tokens against current authorization and revocation

Check live token expiry, durable family revocation, continuing approval and the application allowlist. Keep authentication time fixed at issuance and report consistent validity after another sign-in.

## Review boundary

Compare with `dcl/delegated-access/token-refresh`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Check live token expiry, durable family revocation, continuing approval and the application allowlist. Keep authentication time fixed at issuance and report consistent validity after another sign-in.

## Changed files

- `app/controllers/openid_connect/introspect_controller.rb`
- `app/forms/openid_connect_introspect_form.rb`
- `spec/forms/openid_connect_introspect_form_spec.rb`
- `spec/requests/openid_connect/introspect_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
