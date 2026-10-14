# Add per-site key cryptographic primitives

Add recipient-key validation, root wrapping and browser sealing primitives with focused cryptographic tests.

## Review boundary

Compare with `dcl/delegated-access/document-release`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Add recipient-key validation, root wrapping and browser sealing primitives with focused cryptographic tests.

## Changed files

- `app/services/encryption/aes_cipher.rb`
- `app/services/encryption/aes_cipher_v2.rb`
- `app/services/encryption/decipher_error.rb`
- `app/services/site_keys/recipient_jwk.rb`
- `app/services/site_keys/seal_error.rb`
- `app/services/site_keys/sealer.rb`
- `spec/rails_helper.rb`
- `spec/services/encryption/aes_cipher_spec.rb`
- `spec/services/encryption/aes_cipher_v2_spec.rb`
- `spec/services/site_keys/recipient_jwk_spec.rb`
- `spec/services/site_keys/sealer_spec.rb`
- `spec/support/site_key_helper.rb`

## Provenance and verification

Source commit: `046467c839`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
