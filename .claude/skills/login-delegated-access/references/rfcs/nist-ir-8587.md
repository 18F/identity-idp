# NIST IR 8587 — token elements a relying API needs (as cited by the companion document)

The companion requirements document (INT-4) cites NIST IR 8587 §5.2.1.1 for the list of elements a
resource server needs from a token it relies on: issuer, audience, subject, acting party, assurance,
issuance and expiry times, a unique token identifier, the authentication time and the client. This
digest records how the introspection response supplies each element; it does not reproduce the NIST
text. The code does not cite the report directly. Fetch the publication from
https://csrc.nist.gov/publications (search "NIST IR 8587") before quoting it.

## Elements the implementation supplies (companion INT-4 as amended)

- **Issuer.** `iss` is Login.gov's root URL (`OpenidConnectIntrospectForm#token_members`,
  `app/forms/openid_connect_introspect_form.rb`).
- **Audience.** `aud` is the resource server identifier the token was issued for (RFC 8707).
- **Subject.** `sub` is the agency-level pairwise identifier (`DelegatedTokenClaims#agency_sub`,
  `app/services/delegated_token_claims.rb`; INT-5, D35).
- **Acting party.** `act: { sub: <service provider issuer> }` (RFC 8693 §4.1), always present in an
  active response to the agency.
- **Client.** `client_id` is the service provider's issuer (RFC 8693 §4.3).
- **Assurance.** `acr` (identity assurance) and `aal` (authentication assurance) in the vocabulary
  userinfo uses (`DelegatedTokenClaims#acr`, `#aal_acr`; INT-12).
- **Times.** `iat` and `exp` from the live entry; `auth_time` is when the person last authenticated
  to the service provider (`identities.last_authenticated_at`), the sign-in the delegation rests on
  (`#auth_time`); the SAML `AuthnInstant` carries the same instant.
- **Unique token identifier.** `jti` is the hex SHA-256 digest of the token (D63, E101);
  `delegation_id` identifies the approval and is shared by every token in the family.
- **Key binding.** `cnf.jkt` and `token_type: DPoP` for a bound token (RFC 7800, RFC 9449 §6).

## Deliberate choices and deviations

- **Supplied by introspection, not inside the token** (D29): the token is opaque, so the agency
  obtains these elements from Login.gov on every request and sees revocation at once (D37).
- **`jti` is the digest itself.** INT-4 first asked for a value derived from the digest; D63 chose
  the digest, which is also the key of the live entry (E101).
- **SAML counterpart.** The assertion carries the same facts as `Issuer`, `Audience`, `NameID`,
  `actor`, `delegation_id`, `AuthnInstant`, `IssueInstant`/`NotOnOrAfter` and the `ID` (companion §15.4).

## Questions this digest answers

- Where is the NIST list honored? In `OpenidConnectIntrospectForm#resource_server_response`.
- Is `act` optional? Not in Login.gov's active response to the agency (INT-4).
- What is `auth_time`? The service provider sign-in's last authentication instant, not the token's issuance.
- Does the service provider's limited response carry these elements? Only `iss`, `aud`, `scope`, `iat`, `exp`, `token_type`, `cnf`, `delegation_id` and its own `sub` (INT-14).
- Can I quote NIST IR 8587 from this digest? No; fetch the publication.

## When to fetch the full text

Fetch §5.2.1.1 before changing which members the active response carries, and whenever a reviewer
asks for the NIST basis of INT-4. https://csrc.nist.gov/publications
