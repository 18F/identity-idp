# Wire delegated endpoints with compatible disabled behavior

Route supported grants and publish gated discovery metadata. When delegated access is disabled, retain the existing token-form errors instead of introducing unsupported_grant_type responses.

## Review boundary

Compare with `dcl/delegated-access/token-revocation`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Route supported grants and publish gated discovery metadata. When delegated access is disabled, retain the existing token-form errors instead of introducing unsupported_grant_type responses.

## Changed files

- `app/presenters/openid_connect_configuration_presenter.rb`
- `config/application.rb`
- `config/initializers/job_configurations.rb`
- `spec/presenters/openid_connect_configuration_presenter_spec.rb`
- `spec/requests/openid_connect/token_spec.rb`
- `spec/requests/openid_connect_cors_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
