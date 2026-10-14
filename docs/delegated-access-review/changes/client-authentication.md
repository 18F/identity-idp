# Authenticate callers of delegated endpoints

Verify confidential-client assertions against registered keys and distinguish them from public-client proof handling. Share endpoint error and attribution plumbing.

## Review boundary

Compare with `dcl/delegated-access/dpop-proofs`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Verify confidential-client assertions against registered keys and distinguish them from public-client proof handling. Share endpoint error and attribution plumbing.

## Changed files

- `app/controllers/concerns/openid_connect/delegated_endpoint_concern.rb`
- `app/forms/concerns/delegated_access_client_handling.rb`
- `app/services/resource_server_authenticator.rb`
- `spec/services/resource_server_authenticator_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
