# Exchange approved sign-in tokens for agency access

Validate caller, subject token, approval, requested resource and scope before opening one bounded family. Save the original authentication time and issue the registered token format.

## Review boundary

Compare with `dcl/delegated-access/account-management`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Validate caller, subject token, approval, requested resource and scope before opening one bounded family. Save the original authentication time and issue the registered token format.

## Changed files

- `app/controllers/openid_connect/token_controller.rb`
- `app/forms/openid_connect_token_exchange_form.rb`
- `app/forms/openid_connect_unsupported_grant_form.rb`
- `spec/controllers/openid_connect/token_controller_spec.rb`
- `spec/forms/openid_connect_unsupported_grant_form_spec.rb`
- `spec/requests/openid_connect/token_exchange_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
