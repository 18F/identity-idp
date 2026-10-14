# Recover per-site keys using a personal key

Allow identity-verified users to recover their site-key root with their personal key.

## Review boundary

Compare with `dcl/delegated-access/site-key-recovery`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Allow identity-verified users to recover their site-key root with their personal key.

## Changed files

- `app/controllers/accounts/personal_keys_controller.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/idv/personal_key_controller.rb`
- `app/controllers/site_keys/recoveries_controller.rb`
- `app/controllers/two_factor_authentication/personal_key_verification_controller.rb`
- `app/controllers/users/verify_password_controller.rb`
- `app/controllers/users/verify_personal_key_controller.rb`
- `app/models/site_key_root.rb`
- `app/services/analytics_events.rb`
- `app/services/idv/profile_maker.rb`
- `app/services/idv/session.rb`
- `app/services/site_keys/root_cipher.rb`
- `app/services/site_keys/vault.rb`
- `app/services/user_profiles_encryptor.rb`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/locales/fr.yml`
- `config/locales/zh.yml`
- `db/primary_migrate/20261003110003_add_personal_key_to_site_key_roots.rb`
- `db/schema.rb`
- `spec/controllers/accounts/personal_keys_controller_spec.rb`
- `spec/controllers/two_factor_authentication/personal_key_verification_controller_spec.rb`
- `spec/controllers/users/verify_password_controller_spec.rb`
- `spec/controllers/users/verify_personal_key_controller_spec.rb`
- `spec/forms/update_user_password_form_spec.rb`
- `spec/models/site_key_root_spec.rb`
- `spec/services/idv/profile_maker_spec.rb`
- `spec/services/site_keys/root_cipher_spec.rb`
- `spec/services/site_keys/vault_spec.rb`

## Provenance and verification

Source commit: `581fd02218`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
