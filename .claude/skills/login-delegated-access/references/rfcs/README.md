# RFC knowledge base for delegated access

One digest per specification the delegated-access code relies on. Each digest states the sections
the implementation honors, names the class and method that honors each one, points to the decision
(`Dnn` in the plan's section 9) or companion row (`EXC-`, `INT-`, `REF-`, `SAML-`, `DISC-`, `Ennn`)
that interprets it, lists the deliberate choices made where the specification leaves latitude, and
answers the questions developers ask most. Digests describe the code at the top of the stack.

## Digests

| Digest | Specification | What it governs here | Code it most affects | Branch that owns the code |
|---|---|---|---|---|
| [rfc6749.md](rfc6749.md) | OAuth 2.0 Authorization Framework | Token endpoint, client authentication, error objects, refresh grant | `OpenidConnect::TokenController`, `DelegatedAccessClientHandling`, `OpenidConnectUnsupportedGrantForm`, `OpenidConnectRefreshTokenForm` | `delegated-access-token-exchange` (dispatch, unsupported grant), `delegated-access-token-lifecycle` (concern, refresh) |
| [rfc7636.md](rfc7636.md) | PKCE | The public client's code exchange; PKCE refused on delegated grants | `OpenidConnectAuthorizeForm`, `OpenidConnectTokenForm`, `DelegatedAccessClientHandling#validate_code_verifier_absent` | `main` behavior; refusal on `delegated-access-token-lifecycle` |
| [rfc7523.md](rfc7523.md) | JWT client authentication (`private_key_jwt`) | Confidential service providers and agency APIs | `ResourceServerAuthenticator` | `delegated-access-token-exchange` |
| [rfc7638.md](rfc7638.md) | JWK Thumbprint | The DPoP key's identity (`dpop_jkt`, `cnf.jkt`) | `DpopProofVerifier.thumbprint`, `OpenidConnectAuthorizeForm#validate_dpop_jkt` | `delegated-access-dpop` |
| [rfc7800.md](rfc7800.md) | `cnf` claim | Key binding reported by introspection | `OpenidConnectIntrospectForm#token_members` | `delegated-access-introspection` |
| [rfc8693.md](rfc8693.md) | Token Exchange | The exchange request, response, errors, token type URNs, `act` | `OpenidConnectTokenExchangeForm`, `OpenidConnectIntrospectForm#resource_server_response` | `delegated-access-token-exchange`, `delegated-access-introspection` |
| [rfc8707.md](rfc8707.md) | Resource Indicators | The one `resource` an exchange names | `OpenidConnectTokenExchangeForm#validate_resource`, `TokenExchangeResourceServer` | `delegated-access-token-exchange` (`delegated-access-registry` for the model) |
| [rfc7662.md](rfc7662.md) | Token Introspection | Agency verification; the public client's own introspection | `OpenidConnectIntrospectForm`, `DelegatedTokenClaims`, `DelegatedTokenStore.read` | `delegated-access-introspection` |
| [rfc7009.md](rfc7009.md) | Token Revocation | Ending a family or one token early | `OpenidConnectRevokeForm`, `TokenExchangeRefreshToken.revoke_family!`, `DelegatedTokenStore.revoke_token` | `delegated-access-token-lifecycle` |
| [rfc9449.md](rfc9449.md) | DPoP | Key binding for the public client at every endpoint | `DpopProofVerifier`, `ReplayGuard`, `AccessTokenVerifier`, `OpenidConnectTokenForm#validate_dpop_proof`; call sites in the exchange, refresh, revoke and introspect forms | `delegated-access-dpop` (verifier, guard, userinfo, code binding); call sites on their own branches |
| [rfc9700.md](rfc9700.md) | OAuth 2.0 Security BCP | Refresh rotation, reuse detection, sender-constraining, lifetimes | `TokenExchangeRefreshToken`, `OpenidConnectRefreshTokenForm#rotate_and_mint!`, `TokenExchangeToken.lifetime_seconds_for` | `delegated-access-token-lifecycle` |
| [oidc-core.md](oidc-core.md) | OpenID Connect Core 1.0 | Authentication request, `consent_required`, userinfo claim shapes, pairwise `sub`, `private_key_jwt`, third-party-initiated login | `OpenidConnectAuthorizeForm`, `DelegatedTokenClaims`, `AccessTokenVerifier` | `delegated-access-consent` (scopes), `delegated-access-introspection` (claims); third-party login is reference applications only |
| [saml2.md](saml2.md) | SAML 2.0 Core and Profiles | The SAML assertion issued as a token | `DelegatedSamlAssertion`, `SamlIdpExtensions::AssertionBuilder` | `delegated-access-saml-assertions` |
| [rfc6750.md](rfc6750.md) | Bearer Token Usage | Userinfo authentication and the `WWW-Authenticate` vocabulary | `AccessTokenVerifier` | `delegated-access-dpop` (DPoP scheme); bearer path is `main` |
| [rfc8414.md](rfc8414.md) | Authorization Server Metadata, OpenID Connect Discovery | The discovery document's delegation members | `OpenidConnectConfigurationPresenter` | `delegated-access-operations` |
| [rfc7519.md](rfc7519.md) | JSON Web Token | Claims and validation of client assertions and proofs | `ResourceServerAuthenticator`, `DpopProofVerifier` | `delegated-access-token-exchange`, `delegated-access-dpop` |
| [rfc7517.md](rfc7517.md) | JSON Web Key (with RFC 7518) | The `jwk` header of a proof | `DpopProofVerifier#import_public_key` | `delegated-access-dpop` |
| [rfc8725.md](rfc8725.md) | JWT Best Current Practices | Hardening of both JWT verifiers | `ResourceServerAuthenticator`, `DpopProofVerifier` | `delegated-access-token-exchange`, `delegated-access-dpop` |
| [nist-ir-8587.md](nist-ir-8587.md) | NIST IR 8587 §5.2.1.1 (as cited by INT-4) | The element list the active introspection response satisfies | `OpenidConnectIntrospectForm#resource_server_response` | `delegated-access-introspection` |

File paths in the digests are repository-relative (`app/forms/...`, `app/services/...`,
`app/models/...`, `app/presenters/...`, `app/controllers/...`, `lib/saml_idp_extensions/...`).
Branch names follow the stack order in `CLAUDE.md` section 2; the digests describe the code as it
stands on the top of the stack, so a method may have moved to a lower branch by rebase.

## How to use

1. **Read the digest first.** It names the section, the normative statement in a sentence or two,
   the code that honors it and the decision that interpreted it. Most questions end here.
2. **Fetch the full text only when the digest does not settle the question**: a new request
   parameter, an error code the digest does not map, a reviewer asking for the exact wording.
   RFCs: `https://www.rfc-editor.org/rfc/rfcNNNN.txt`. OpenID Connect Core:
   `https://openid.net/specs/openid-connect-core-1_0.html`; Discovery:
   `https://openid.net/specs/openid-connect-discovery-1_0.html`. SAML 2.0 Core and Profiles:
   `https://docs.oasis-open.org/security/saml/v2.0/saml-core-2.0-os.pdf` and
   `https://docs.oasis-open.org/security/saml/v2.0/saml-profiles-2.0-os.pdf`. Each digest ends with
   the sections worth reading in full.
3. **Never paraphrase a normative requirement from memory** when the digest and the text are
   available. Quote the section number and the text's own words (MUST, SHOULD, MAY) in code
   comments and documents; where this knowledge base and the text disagree, the text wins and the
   digest is corrected.
4. **Record a new interpretation as a decision**, not as a digest edit alone: a `Dnn` entry in the
   plan's section 9 and an Appendix E row in the companion, then update the digest's "Deliberate
   choices and deviations" to point at it (see `CLAUDE.md` section 1).
5. **Code comments cite the standard, never the requirement identifier** (`CLAUDE.md` section 3);
   the digests are where the standard, the identifiers and the code meet.

## Items to confirm against the text

- `rfc9449.md`: the error code RFC 9449 §10 prescribes for a `dpop_jkt` mismatch at the token
  endpoint; the code reports `invalid_dpop_proof` for every proof problem.
- `rfc8693.md`: §2.2.2 directs `invalid_request` for an invalid `subject_token`; this implementation
  answers `invalid_grant` (E26). Deliberate, but the deviation should be named in the integration guide.
- `rfc9449.md`: the number of the Security Considerations section (the project documents cite the
  replay subsection as §11.1); the digest names the subsection by title.
- `nist-ir-8587.md`: the element list is taken from companion INT-4, not from the publication.
