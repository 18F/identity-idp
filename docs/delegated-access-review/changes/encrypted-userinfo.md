# Encrypt userinfo for opted-in confidential service providers

Return JWE userinfo only for explicitly configured service providers with usable registered keys. Keep ordinary JSON responses unchanged.

## Review boundary

Compare with `dcl/delegated-access/registry-seeding`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Return JWE userinfo only for explicitly configured service providers with usable registered keys. Keep ordinary JSON responses unchanged.

## Changed files

- `app/controllers/openid_connect/user_info_controller.rb`
- `app/services/openid_connect/user_info_encryptor.rb`
- `spec/requests/openid_connect/user_info_encrypted_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
