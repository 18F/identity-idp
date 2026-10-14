# Present application-specific delegation consent at sign-in

Show the requested applications and remember choice, persist approval, and release agency fraud signals after consent. Resume the trusted authorization binding decision through sign-in and locale changes.

## Review boundary

Compare with `dcl/delegated-access/authorization-binding`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Show the requested applications and remember choice, persist approval, and release agency fraud signals after consent. Resume the trusted authorization binding decision through sign-in and locale changes.

## Changed files

- `app/controllers/concerns/verify_sp_attributes_concern.rb`
- `app/controllers/openid_connect/authorization_controller.rb`
- `app/controllers/sign_up/completions_controller.rb`
- `app/presenters/completions_presenter.rb`
- `app/presenters/delegation_service_provider_card.rb`
- `app/views/shared/_delegation_application_content.html.erb`
- `app/views/shared/_delegation_service_provider_card.html.erb`
- `app/views/sign_up/completions/_delegation_consent.html.erb`
- `app/views/sign_up/completions/show.html.erb`
- `spec/controllers/openid_connect/authorization_controller_spec.rb`
- `spec/controllers/sign_up/completions_controller_spec.rb`
- `spec/features/openid_connect/delegated_access_consent_spec.rb`
- `spec/presenters/completions_presenter_spec.rb`
- `spec/views/sign_up/completions/show.html.erb_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
