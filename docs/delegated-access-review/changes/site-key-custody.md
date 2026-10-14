# Protect per-site key roots with user credentials

Store site-key roots and maintain their password wrapping through credential changes.

## Review boundary

Compare with `dcl/delegated-access/site-key-crypto`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Store site-key roots and maintain their password wrapping through credential changes.

## Changed files

- `app/controllers/concerns/site_key_concern.rb`
- `app/controllers/password_capture_controller.rb`
- `app/controllers/sign_up/passwords_controller.rb`
- `app/controllers/users/passwords_controller.rb`
- `app/controllers/users/sessions_controller.rb`
- `app/forms/event_disavowal/password_reset_from_disavowal_form.rb`
- `app/forms/reset_password_form.rb`
- `app/forms/update_user_password_form.rb`
- `app/models/service_provider.rb`
- `app/models/site_key_root.rb`
- `app/models/user.rb`
- `app/services/analytics_events.rb`
- `app/services/reset_user_password.rb`
- `app/services/service_provider_updater.rb`
- `app/services/site_keys/root_cipher.rb`
- `app/services/site_keys/root_mismatch_error.rb`
- `app/services/site_keys/vault.rb`
- `config/application.yml.default`
- `config/service_providers.localdev.yml`
- `db/primary_migrate/20261003110000_create_site_key_roots.rb`
- `db/primary_migrate/20261003110001_add_site_key_allowed_to_service_providers.rb`
- `db/schema.rb`
- `lib/identity_config.rb`
- `spec/controllers/concerns/site_key_concern_spec.rb`
- `spec/controllers/password_capture_controller_spec.rb`
- `spec/controllers/sign_up/passwords_controller_spec.rb`
- `spec/controllers/users/delete_controller_spec.rb`
- `spec/controllers/users/passwords_controller_spec.rb`
- `spec/controllers/users/sessions_controller_spec.rb`
- `spec/factories/site_key_roots.rb`
- `spec/forms/event_disavowal/password_reset_from_disavowal_form_spec.rb`
- `spec/forms/reset_password_form_spec.rb`
- `spec/forms/update_user_password_form_spec.rb`
- `spec/models/service_provider_spec.rb`
- `spec/models/site_key_root_spec.rb`
- `spec/services/reset_user_password_spec.rb`
- `spec/services/service_provider_seeder_spec.rb`
- `spec/services/site_keys/root_cipher_spec.rb`
- `spec/services/site_keys/vault_spec.rb`
- `spec/support/site_key_helper.rb`

## Provenance and verification

Source commit: `6b19706b12`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
