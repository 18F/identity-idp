# delegated-access-encrypted-userinfo

## Purpose

Plan 5.14, encrypted userinfo responses. A confidential service provider that opts in on its record receives its userinfo claims as one compact JWE (RFC 7516; RSA-OAEP-256, A256GCM) with content type `application/jwt`, per OpenID Connect Core 1.0 §5.3.2, encrypted to the public key of its first registered certificate, the one its `private_key_jwt` assertions are verified against. Everyone else keeps the plain JSON response unchanged. The whole claims object is encrypted, document-metadata claims under the `document_images` scope included, so the edge, logs and any intermediary see ciphertext. An opted-in record without a usable key is refused, never answered in the clear. Top of the stack; one commit.

## Requirements it satisfies

FR-DOS-12 as amended 2026-10-10 (the end-to-end property for the direct service provider's attributes). Companion §6.5 UINF-1 as amended, UINF-2 (fail closed), UINF-3 (discovery members); §14.2 as amended (no reference application decrypts).

## What it adds / removes and why

Adds:
- Migration `20261010110000_add_userinfo_encrypted_response_alg_to_service_providers`: `service_providers.userinfo_encrypted_response_alg` (string, nullable). The record opts in by naming the algorithm; nil keeps plain JSON. Why a column and not a configuration key: partner configuration lives on the record (D7), and the registry already holds the certificate the response is encrypted to.
- `ServiceProvider::USERINFO_ENCRYPTED_RESPONSE_ALGS` (`RSA-OAEP-256` only) with an inclusion validation; `#userinfo_encrypted_response?`; `#userinfo_encryption_key` (public key of `ssl_certs.first`; nil for a `pkce` record, a missing certificate or one that cannot be parsed); `#warn_if_userinfo_encryption_unusable` (a logged warning when an opt-in cannot be honored).
- `OpenidConnect::UserInfoEncryptor` (`ALG`, `ENC`, `NoUsableKeyError`): JSON of the claims hash becomes the plaintext of one compact JWE whose header carries only `alg` and `enc` (no `kid`: one registered key per record, owned by the decrypting party; not signed inside the JWE). A key that is not `OpenSSL::PKey::RSA` raises.
- `OpenidConnect::UserInfoController#show`: the presenter is unchanged; an opted-in record is rendered as `application/jwt`, everyone else as JSON. `NoUsableKeyError` and `OpenSSL::OpenSSLError` become HTTP 500 `server_error` with the locale description `openid_connect.user_info.errors.encryption_unavailable` and the analytics event `openid_connect_userinfo_encryption_failed` (`client_id`, `error`); no claim reaches that response. `openid_connect_bearer_token` gains `encrypted`.
- `OpenidConnectConfigurationPresenter`: `userinfo_encryption_alg_values_supported` and `userinfo_encryption_enc_values_supported`, unconditional; they state the fixed algorithms, not whether anyone opted in.
- `ServiceProviderSeeder` and `ServiceProviderUpdater` call `warn_if_userinfo_encryption_unusable` after every write.
- Locale key in en, es, fr and zh.

Removes: nothing. No fixture record opts in and no reference application changes; the public reference applications must not suggest a general feature (D81).

## Key decisions

- D50 (2026-10-09): planned, not built; the whole bundle as a JWE to the certificate registered for the token's own service provider, never a key named in the request.
- D81 (2026-10-10): built as above. Confidential clients only (a public client has no registered key; its DPoP key is a signing key). Fail closed. Whole object, document-metadata claims included. One partner's need: no decrypting reference application, no fixture opt-in; verified by request specs. Deferred and documented: a separate registered encryption certificate (key separation, NIST IR 8587 §5.2.1.2); per-field encryption, which must not conflict with per-site keys (5.16) or the document-image attributes for specific relying parties (5.12). Rejected: `identity-oidc-sinatra` decrypting (reverted); a fixture opt-in (reverted); an `application.yml` allowlist.
- Standing: delegated tokens remain refused at userinfo (D19, EXC-6, EXC-18).

## Key files

Services: `app/services/openid_connect/user_info_encryptor.rb`, `app/services/service_provider_seeder.rb`, `app/services/service_provider_updater.rb`, `app/services/analytics_events.rb` (`openid_connect_bearer_token` `encrypted`; `openid_connect_userinfo_encryption_failed`).
Controller and presenters: `app/controllers/openid_connect/user_info_controller.rb`, `app/presenters/openid_connect_configuration_presenter.rb` (the userinfo presenter is untouched).
Model and schema: `app/models/service_provider.rb`, `db/primary_migrate/20261010110000_add_userinfo_encrypted_response_alg_to_service_providers.rb`, `db/schema.rb`.
Locales: `config/locales/{en,es,fr,zh}.yml` (`openid_connect.user_info.errors.encryption_unavailable`).
Specs: `spec/requests/openid_connect/user_info_encrypted_spec.rb` (12 examples), `spec/models/service_provider_spec.rb`, `spec/presenters/openid_connect_configuration_presenter_spec.rb`, `spec/services/service_provider_seeder_spec.rb`, `spec/services/service_provider_updater_spec.rb`, `spec/requests/openid_connect_userinfo_spec.rb` and `spec/controllers/openid_connect/user_info_controller_spec.rb` (the `encrypted: false` property).

## Commits

- `561eed4d2b` FR-DOS-12: userinfo responses are encrypted to the opted-in service provider's registered certificate

## How to review

Diff against `delegated-access-config-content`. Start with the request spec: it decrypts the JWE with the test certificate's private key and compares the result with the plain response, checks the header carries only `alg` and `enc`, and asserts that no claim value appears in the clear, including the document-metadata claims under `document_images`. Then the fail-closed cases: no certificate, a certificate naming a file that does not exist, and a public client with a certificate pasted on its record each answer 500 `server_error` with no claim in the body and log `openid_connect_userinfo_encryption_failed`; confirm the controller has no plaintext fallback path. Then: a delegated token is still refused before any response is built; a record that did not opt in receives the plain response exactly as before; discovery carries the two members with the fixed values. Must not change for existing clients: the plain response, byte for byte, for every record without the column; the bearer and DPoP checks of `AccessTokenVerifier`. Verified locally: 273 examples across the touched specs, rubocop and the analytics lints clean, gitleaks clean on the commit range; full suite pending.

## Known open items and later amendments

- A separate registered encryption certificate, so the decrypting key is not the client-assertion signing key (key separation); documented, not built.
- Per-field encryption; documented, not built, and constrained not to conflict with per-site keys (5.16) or the document-image attributes for specific relying parties (5.12).
- No reference application decrypts and the end-to-end harness does not exercise the feature, by design (D81); coverage is the request spec only.
- Full-suite run on this branch as the top of the stack is pending before push.

## Depends on / depended on by

Depends on `delegated-access-registry` (the service provider record and the certificates `ssl_certs` reads) and, by position, on `delegated-access-config-content`. Depended on by nothing; it is the top of the stack.
