# Seal per-site keys to the requesting browser

Validate opted-in browser keys and return sealed values in a client-side fragment. Ignore optional site_key_jwk values when the feature or provider opt-in is disabled.

## Review boundary

Compare with `dcl/delegated-access/site-key-custody`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Validate opted-in browser keys and return sealed values in a client-side fragment. Ignore optional site_key_jwk values when the feature or provider opt-in is disabled.

## Changed files

- `app/controllers/openid_connect/authorization_controller.rb`
- `app/forms/openid_connect_authorize_form.rb`
- `app/services/analytics_events.rb`
- `app/services/site_keys/vault.rb`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/locales/fr.yml`
- `config/locales/zh.yml`
- `spec/controllers/openid_connect/authorization_controller_spec.rb`
- `spec/forms/openid_connect_authorize_form_spec.rb`
- `spec/support/site_key_helper.rb`

## Provenance and verification

Source commit: `34f3735e45`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
