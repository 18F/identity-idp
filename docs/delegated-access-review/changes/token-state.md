# Store approvals and bounded delegated token families

Model approvals, issuance records and rotating refresh credentials. Keep raw tokens out of durable storage, use Redis TTLs for access tokens, and preserve family security independently of browser sessions.

## Review boundary

Compare with `dcl/delegated-access/client-authentication`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Model approvals, issuance records and rotating refresh credentials. Keep raw tokens out of durable storage, use Redis TTLs for access tokens, and preserve family security independently of browser sessions.

## Changed files

- `app/jobs/expire_delegated_refresh_tokens_job.rb`
- `app/models/token_exchange_grant.rb`
- `app/models/token_exchange_refresh_token.rb`
- `app/models/token_exchange_token.rb`
- `app/services/attempts_api/delegated_event_writer.rb`
- `app/services/attempts_api/tracker_events.rb`
- `app/services/delegated_access/opaque_token.rb`
- `app/services/delegated_access_events.rb`
- `app/services/delegated_token_store.rb`
- `spec/factories/token_exchange_grants.rb`
- `spec/factories/token_exchange_refresh_tokens.rb`
- `spec/factories/token_exchange_tokens.rb`
- `spec/jobs/expire_delegated_refresh_tokens_job_spec.rb`
- `spec/models/token_exchange_grant_spec.rb`
- `spec/models/token_exchange_refresh_token_spec.rb`
- `spec/models/token_exchange_token_spec.rb`
- `spec/services/delegated_access/opaque_token_spec.rb`
- `spec/services/delegated_token_store_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
