# delegated-access-site-keys

## Purpose

Plan 5.16, per-site keys: a key unique to a person and a service provider, the same on every device, delivered only to the service provider's browser. The branch is a port of the five per-site-keys pull requests (#13618 to #13622 on `18F/identity-idp`), cherry-picked with their original authors and commit messages preserved. It is independent of the delegation chain and has no requirement rows of its own; it sits after the account page and before the DPoP branch so every delegation branch from the exchange on builds on it (D64).

## Requirements it satisfies

None of the FR-ONB/CEN/CUX/TOK/VER/FRD/BIL/OPS rows. Functional requirements section 12 (FR-KEY-1 to FR-KEY-7) describes the ported feature; companion §17 and Appendix E row E92. Plan section 8 lists it as "supporting key-custody primitives, no requirement rows of its own".

## What it adds / removes and why

Adds (nothing is removed):
- Sealing primitives (#13618): `SiteKeys::RecipientJwk` accepts only a P-256 public JWK (WebCrypto metadata members ignored, a private `d`, off-curve points or wrong-length coordinates rejected); `SiteKeys::Sealer` wraps a key with ECDH-ES, HKDF-SHA256 and AES-256-GCM, info and AAD `"login.gov site key wrap v1\n<client_id>"` so a sealed key is bound to one service provider. `Encryption::AesCipher` and `AesCipherV2` raise `Encryption::DecipherError` on authentication failure.
- Custody (#13619): `site_key_roots` holds 32 random bytes per user wrapped with the profile-PII scheme (scrypt of the password plus KMS); `SiteKeys::Vault` unwraps at password entry and keeps the root KMS-encrypted in the session with a fingerprint of the wrap; a root is created only for a service provider with `site_key_allowed`, settable from `service_providers.yml` only (`ServiceProviderUpdater` ignores it). Password change re-wraps under a row lock; every password reset path deletes the root. Analytics `site_key_root_created`, `site_key_root_unlock_failed`. All behind `site_key_enabled` (default false).
- Release on OIDC authorization (#13620): `OpenidConnectAuthorizeForm` validates `site_key_jwk` and `server_scope`; `link_identity_to_service_provider` passes `server_scope`, so `token_exchange:*` scopes still reach the identity while email is withheld when a site key is requested.
- Recovery after a password reset (#13621, `SiteKeys::RecoveryCode`, `site_keys/recovery_codes`) and with the personal key for identity-verified users (#13622, `site_keys/recoveries`); migrations add the recovery-code and personal-key wraps.

Why ported here: the sealed key is held in the service provider's page like its DPoP key; no server of the service provider sees either (D19). Nothing in the delegation branches reads a site key root and nothing here reads a grant, token or resource server.

## Key decisions

- D56: #13618 and #13619 ported first as their own branch; the rest of the series followed on 2026-10-10 (plan section 7 amendment), so all five are on the branch.
- D64: position in the stack (after account page, before DPoP).

## Key files

Models: `app/models/site_key_root.rb`, `app/models/service_provider.rb` (`site_key_allowed?`), `app/models/user.rb`.
Forms: `app/forms/site_keys/recovery_form.rb`, `app/forms/openid_connect_authorize_form.rb`, `app/forms/reset_password_form.rb`, `app/forms/update_user_password_form.rb`, `app/forms/event_disavowal/password_reset_from_disavowal_form.rb`.
Services: `app/services/site_keys/{recipient_jwk,sealer,vault,root_cipher,recovery_code}.rb`, `app/services/site_keys/{root_mismatch_error,seal_error}.rb`, `app/services/encryption/{aes_cipher,aes_cipher_v2,decipher_error}.rb`, `app/services/reset_user_password.rb`, `app/services/user_profiles_encryptor.rb`, `app/services/idv/profile_maker.rb`, `app/services/rate_limiter.rb`, `app/services/service_provider_updater.rb`.
Controllers/views: `app/controllers/concerns/site_key_concern.rb`, `app/controllers/site_keys/{recoveries,recovery_codes}_controller.rb`, `app/controllers/openid_connect/authorization_controller.rb`, the password, session and personal-key controllers, `app/views/site_keys/**`, `app/views/accounts/_site_key_recovery_code.html.erb`.
Migrations: `20261003110000_create_site_key_roots`, `20261003110001_add_site_key_allowed_to_service_providers`, `20261003110002_add_recovery_code_to_site_key_roots`, `20261003110003_add_personal_key_to_site_key_roots` (timestamps predate the delegation migrations, so a fresh database applies them first).
Specs: `spec/services/site_keys/*_spec.rb`, `spec/models/site_key_root_spec.rb`, `spec/controllers/site_keys/*`, `spec/controllers/concerns/site_key_concern_spec.rb`, `spec/lib/session_encryptor_spec.rb`, `spec/support/site_key_helper.rb`.
Config/locales: `config/routes.rb` (`/account/site_key/*`), `config/application.yml.default`, `lib/identity_config.rb` (`site_key_enabled`), `lib/session_encryptor.rb`, `config/service_providers.localdev.yml`, `config/locales/{en,es,fr,zh}.yml`.

## Commits

Ported; original authors and messages preserved, no FR identifiers in the subjects.
- `07982f3614` Add sealing primitives for per-site keys
- `35a390fb0c` Store per-site key roots wrapped under the user's password
- `ec929f2ec3` Release sealed per-site keys on OIDC authorization
- `d614c18844` Let users recover per-site keys after a password reset
- `56f392c565` Let identity-verified users recover per-site keys with their personal key

## How to review

Diff against `delegated-access-account-page`. Review as a port, not as new design: compare with the upstream pull requests; the local conflict resolutions were in `app/models/service_provider.rb` and its spec (delegation columns beside `site_key_allowed`), `db/schema.rb`, and `OpenidConnectAuthorizeForm` (site-key validation and `server_scope` beside the delegation-scope validation). Check first that `site_key_enabled` is false by default and that `ServiceProviderUpdater` cannot set `site_key_allowed`. Specs: the `SiteKeys::*` specs, the authorize form spec, the password and session controller specs. Must not change for existing clients: with the flag off no root is created, no password path changes, and the authorize form behaves as before for a request without `site_key_jwk`.

## Known open items and later amendments

- Known limitation from the source: a transient unlock failure followed by a password change deletes the root; the later pull requests drop only the password wrap.
- The site-key request digest hashes `client_id`, `state` and `site_key_jwk` only, not `dpop_jkt`, so the two authorize parameters coexist without interaction (plan section 7 amendment).
- Whether a released site key should ever be tied to a delegation is left to future work (plan 5.16).

## Depends on / depended on by

Depends on nothing in the delegation chain; placed after `delegated-access-account-page` by D64. Depended on by `delegated-access-dpop` and everything above it by position, and by the authorize-form changes that must coexist with `dpop_jkt`.
