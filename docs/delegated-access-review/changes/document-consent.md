# Collect document-sharing consent

Collect explicit purpose-specific consent before document sharing; existing sign-ins keep their consent path.

## Review boundary

Compare with `dcl/delegated-access/document-capture`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Collect explicit purpose-specific consent before document sharing; existing sign-ins keep their consent path.

## Changed files

- `app/controllers/concerns/verify_sp_attributes_concern.rb`
- `app/controllers/sign_up/completions_controller.rb`
- `app/presenters/completions_presenter.rb`
- `app/services/analytics_events.rb`
- `app/views/sign_up/completions/_biometric_sharing_consent.html.erb`
- `app/views/sign_up/completions/show.html.erb`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/locales/fr.yml`
- `config/locales/zh.yml`
- `spec/controllers/concerns/verify_sp_attributes_concern_spec.rb`
- `spec/controllers/sign_up/completions_controller_spec.rb`

## Provenance and verification

Source commit: `c6b5c39622`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
