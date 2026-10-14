# Recover per-site keys after password reset

Add recovery-code workflows for roots that cannot be opened after a password reset.

## Review boundary

Compare with `dcl/delegated-access/site-key-browser`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Add recovery-code workflows for roots that cannot be opened after a password reset.

## Changed files

- `app/controllers/concerns/site_key_concern.rb`
- `app/controllers/frontend_log_controller.rb`
- `app/controllers/openid_connect/authorization_controller.rb`
- `app/controllers/site_keys/recoveries_controller.rb`
- `app/controllers/site_keys/recovery_codes_controller.rb`
- `app/forms/site_keys/recovery_form.rb`
- `app/models/site_key_root.rb`
- `app/presenters/account_show_presenter.rb`
- `app/services/analytics_events.rb`
- `app/services/rate_limiter.rb`
- `app/services/site_keys/recovery_code.rb`
- `app/services/site_keys/root_cipher.rb`
- `app/services/site_keys/vault.rb`
- `app/views/accounts/_site_key_recovery_code.html.erb`
- `app/views/accounts/actions/_manage_site_key_recovery_code.html.erb`
- `app/views/accounts/show.html.erb`
- `app/views/partials/personal_key/_key.html.erb`
- `app/views/shared/_personal_key_input.html.erb`
- `app/views/site_keys/recoveries/confirm_destroy.html.erb`
- `app/views/site_keys/recoveries/new.html.erb`
- `app/views/site_keys/recoveries/rate_limited.html.erb`
- `app/views/site_keys/recovery_codes/new.html.erb`
- `app/views/site_keys/recovery_codes/show.html.erb`
- `config/application.yml.default`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/locales/fr.yml`
- `config/locales/zh.yml`
- `config/routes.rb`
- `db/primary_migrate/20261003110002_add_recovery_code_to_site_key_roots.rb`
- `db/schema.rb`
- `lib/identity_config.rb`
- `lib/session_encryptor.rb`
- `spec/controllers/concerns/site_key_concern_spec.rb`
- `spec/controllers/openid_connect/authorization_controller_spec.rb`
- `spec/controllers/site_keys/recoveries_controller_spec.rb`
- `spec/controllers/site_keys/recovery_codes_controller_spec.rb`
- `spec/controllers/users/passwords_controller_spec.rb`
- `spec/forms/event_disavowal/password_reset_from_disavowal_form_spec.rb`
- `spec/forms/reset_password_form_spec.rb`
- `spec/forms/site_keys/recovery_form_spec.rb`
- `spec/forms/update_user_password_form_spec.rb`
- `spec/lib/session_encryptor_spec.rb`
- `spec/models/site_key_root_spec.rb`
- `spec/services/reset_user_password_spec.rb`
- `spec/services/site_keys/recovery_code_spec.rb`
- `spec/services/site_keys/root_cipher_spec.rb`
- `spec/services/site_keys/vault_spec.rb`
- `spec/support/site_key_helper.rb`

## Provenance and verification

Source commit: `30ffd37784`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
