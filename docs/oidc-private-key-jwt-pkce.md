# Optional PKCE for confidential OIDC clients

`private_key_jwt` authenticates the client. PKCE binds authorization code redemption
to a verifier generated for that transaction. Confidential clients should use both
once this capability is enabled in their Login.gov environment.

## Configuration and behavior

`openid_connect_private_key_jwt_pkce_enabled` defaults to `false`. It controls
admission of new PKCE authorization requests for service providers configured with
`pkce: false` (private-key authentication). No partner configuration change is needed.

- Flag disabled: those clients can continue without PKCE; requests containing either
  PKCE authorization parameter are rejected with `invalid_request`.
- Flag enabled: both parameters are required when either is supplied. Only `S256`
  and a 43-character unpadded base64url challenge are accepted.
- A stored challenge always requires a matching verifier, regardless of the current
  flag value. Missing, malformed, mismatched, or unsolicited verifiers result in
  `invalid_grant`, with no tokens issued.
- A confidential client must still supply a valid assertion and assertion type.
  A valid verifier cannot substitute for client authentication.
- Existing `pkce: true` public clients remain supported. Legacy `pkce: nil` clients
  retain their existing ability to use either mode. When an assertion is supplied
  on a legacy PKCE transaction, both proofs are validated. The flag does not change
  legacy registration policy; do not set a confidential client's configuration to
  `nil` to work around the flag.

The existing identity record binds the challenge to its authorization code; no
migration is needed. `S256` is the sole supported method, so token verification
always uses SHA-256. A subsequent authorization replaces the code and challenge,
including clearing the challenge when PKCE is absent.

Input validation is now stricter for all PKCE clients: verifiers must contain
43–128 characters from `A-Z`, `a-z`, `0-9`, `-`, `.`, `_`, and `~`. Newly submitted
challenges must be unpadded base64url. Existing stored padded challenges remain
verifiable. Review partner compatibility in sandbox before release.

## Partner integration example

Generate and retain a fresh verifier on the server for each authorization attempt:

```ruby
verifier = SecureRandom.urlsafe_base64(32)
challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
```

Store the verifier with the user's authorization transaction. Add the following
to the existing authorization request, retaining normal `state` and `nonce` checks:

```text
code_challenge=<challenge>
code_challenge_method=S256
```

On the server, exchange the returned code using a form-encoded POST to
`/api/openid_connect/token`:

```text
grant_type=authorization_code
code=<authorization code>
client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
client_assertion=<signed JWT>
code_verifier=<verifier retained for this transaction>
```

Keep the private key and verifier on the server. Do not retry a failed PKCE
exchange by dropping the verifier. Start a fresh authorization if the transaction
cannot be completed. Do not log verifiers, assertions, codes, or tokens.

## Rollout plan

The DRI coordinates release engineering, security, operations, and partner support.
Before production enablement, assign a named operator and rollback owner, record
the release version and current flag value, and obtain a baseline of token success
rates and latency by integration and authentication mode.

1. **Engineering/security:** Run authorization, token, persistence, and end-to-end
   regression tests. Verify missing assertions, invalid signatures, missing/wrong
   verifiers, unsolicited verifiers, expired/reused codes, and flag changes between
   authorization and redemption. Confirm existing web and mobile clients work.
2. **Release engineering:** Deploy the code with the flag disabled to every instance
   that can process authorization or token requests, across all regions. Do not
   enable admission while any token-serving instance runs the old validator.
   Existing confidential-client requests that supplied ignored challenges now fail
   closed; review telemetry and notify affected partners.
3. **Partner support/engineering:** Enable in sandbox and validate representative
   confidential and public clients, including IRS SADI if available. The flag is
   global within an environment, not a partner allowlist. Coordinate initial partner
   adoption operationally; no new registration setting is introduced.
4. **Operations:** Enable production during a staffed window. Watch authorization
   rejections, token success, verifier errors, assertion errors, and token latency.
   Token events include `code_challenge_present`, `code_verifier_present`,
   `service_provider_pkce`, success, and error details. Correlate with client ID
   without recording protocol secrets. `pkce: false` plus a stored challenge
   identifies the new combined flow.
5. **Partner support:** Publish the combined flow as the preferred confidential-client
   integration on developers.login.gov, with environment availability and examples.
   That documentation is maintained outside this repository; publication is a
   release deliverable. No discovery change is needed to introduce another PKCE
   method because the accepted method remains `S256`.

Before enablement, operators must record numeric alert thresholds and the observation
window based on measured traffic. Proposed starting thresholds: investigate a token
success-rate decrease of 1 percentage point for 10 minutes or a p95 token latency
increase of 20% for 10 minutes; roll back if attributable to this change and sustained.
For low-volume partners, use actual failure counts and synthetic transactions rather
than percentages alone. Any issuance without either required proof is an immediate
security incident and requires stopping new combined transactions.

## Rollback plan

1. Operations disables the flag across authorization-serving instances, stopping
   new combined authorizations for confidential clients. Verify rejection with a
   synthetic authorization request and confirm ordinary web/mobile flows still work.
2. Keep the new token validator deployed. Already issued challenge-bound codes must
   still require both proofs. Confirm a valid in-flight transaction can finish and
   a request missing its verifier fails. Partner support informs affected partners;
   their future authorizations must omit both PKCE parameters only as a deliberate
   coordinated rollback, never as an automatic downgrade of an existing transaction.
3. Prefer a forward fix. Do not revert to a binary that ignores challenges while
   affected codes or pending authorization sessions can still be redeemed or issue
   new codes. Account for the effective code expiration (default 300 seconds), pending
   authorization sessions, all regions, and deployment propagation. Waiting five
   minutes alone is insufficient. Drain or invalidate affected transactions first;
   if safe draining is impossible, fail them closed and require a new authorization.
4. Confirm recovery against the recorded baseline and record the incident, affected
   partners, and evidence before scheduling re-enablement.

## References

- [RFC 7636: PKCE](https://www.rfc-editor.org/rfc/rfc7636.html)
- [RFC 9700: Authorization code security](https://www.rfc-editor.org/rfc/rfc9700.html#section-2.1.1)
- [RFC 9700: PKCE downgrade prevention](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.8.2)
