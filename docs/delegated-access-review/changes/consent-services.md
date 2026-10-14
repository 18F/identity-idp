# Manage delegation approval and revocation

Use shared approval partitioning for sign-in and account-page consent. Revoke access when the user disconnects, suspends, or deletes the account.

## Review boundary

Compare with `dcl/delegated-access/saml-assertions`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Use shared approval partitioning for sign-in and account-page consent. Revoke access when the user disconnects, suspends, or deletes the account.

## Changed files

- `app/controllers/users/delete_controller.rb`
- `app/models/user.rb`
- `app/services/account_delegation_approval.rb`
- `app/services/account_delegation_revocation.rb`
- `app/services/account_reset/delete_account.rb`
- `app/services/revoke_service_provider_consent.rb`
- `app/services/token_exchange_consent.rb`
- `spec/controllers/users/delete_controller_spec.rb`
- `spec/models/user_spec.rb`
- `spec/services/account_delegation_approval_spec.rb`
- `spec/services/account_delegation_revocation_spec.rb`
- `spec/services/account_reset/delete_account_spec.rb`
- `spec/services/revoke_service_provider_consent_spec.rb`
- `spec/services/token_exchange_consent_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
