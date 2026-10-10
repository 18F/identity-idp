# OpenID Connect Core 1.0

OpenID Connect Core defines the sign-in that every delegation rests on: the authentication request,
the ID token, the userinfo endpoint, standard claims, pairwise subject identifiers, `private_key_jwt`
client authentication and the error codes the exchange borrows. Delegated access changes none of the
existing sign-in behavior; it adds delegation scopes to the request, `dpop_jkt` for the public client,
and reuses the userinfo claim shapes and pairwise `sub` in introspection and SAML assertions.
Canonical text: https://openid.net/specs/openid-connect-core-1_0.html

## Sections this implementation relies on

- **§3.1.2.1 Authentication request.** `scope` (with `openid`), `response_type`, `client_id`,
  `redirect_uri`, `state`, `nonce`, `prompt`, `acr_values`; extension parameters are permitted.
  `OpenidConnectAuthorizeForm` (`app/forms/openid_connect_authorize_form.rb`) validates these and
  adds `token_exchange:<value>` scopes (`#validate_delegation_scopes`, only for an identity-verified
  request from a service provider approved for delegation; D14, D15) and `dpop_jkt`
  (`#validate_dpop_jkt`, RFC 9449 §10).
- **§3.1.2.6 Authentication error response.** Defines `consent_required` ("the server requires
  end-user consent") among others. The exchange borrows this code when the person has not approved
  the application that owns the resource (`OpenidConnectTokenExchangeForm#validate_grant`,
  `app/forms/openid_connect_token_exchange_form.rb`; D31). A cancelled consent screen returns
  RFC 6749's `access_denied` (D13).
- **§3.1.3.3 Token response.** The `id_token` is returned with the access token on the
  authorization-code grant only; the exchange and refresh never return one (EXC-5).
- **§5.1 Standard claims, §5.4 scope values.** `given_name`, `family_name`, `birthdate`, `email`,
  `email_verified`, `phone_number`, `address` and the scopes that release them.
  `DelegatedTokenClaims::BUNDLE_SCOPES` (`app/services/delegated_token_claims.rb`) maps an agency's
  attribute-bundle names to the scopes that release the same claims, and `#claims_for` builds them
  with `OpenidConnectAttributeScoper` and `OpenidConnectClaimsFormatter`, so introspection reports
  claim for claim what userinfo would (INT-10, INT-11; D34).
- **§5.3 UserInfo endpoint.** Authenticated with the access token per RFC 6750; `sub` MUST be
  returned. `AccessTokenVerifier` (`app/services/access_token_verifier.rb`) authenticates userinfo;
  its lookup is against `identities` only, so a delegated token is never accepted there (EXC-6).
  The `DPoP` scheme is added for bound tokens (RFC 9449 §7.1).
- **§8, §8.1 Pairwise subject identifiers.** `sub` is per sector, derived so that clients cannot
  correlate. Login.gov's `sub` is per agency: `DelegatedTokenClaims#agency_sub` uses
  `AgencyIdentityLinker` for the agency that owns the API, the same value a direct sign-in produces;
  `OpenidConnectIntrospectForm#service_provider_sub` returns the service provider's own (INT-5; D35).
- **§9 Client authentication, `private_key_jwt`.** The JWT per RFC 7523 with `iss` and `sub` the
  `client_id`, `aud` the issuer or token endpoint URL, `jti` REQUIRED, `exp` REQUIRED, `iat`
  OPTIONAL. `ResourceServerAuthenticator` (`app/services/resource_server_authenticator.rb`) requires
  all of `iss sub aud exp jti` (`REQUIRED_CLAIMS`); INT-6. `none` is the method name for a client
  that sends `client_id` only (`OpenidConnectConfigurationPresenter#token_endpoint_auth_methods_supported`).
- **§4 Initiating login from a third party.** `iss`, `login_hint`, `target_link_uri`; the relying
  party MUST verify `iss` is an issuer it trusts and MUST validate `target_link_uri` against open
  redirects. No identity-idp code: the pattern is implemented in the reference applications
  (companion §16, TPL-1 to TPL-7; plan 5.13).

## Deliberate choices and deviations

- **`consent_required` at the token endpoint.** OpenID Connect defines it for the authorization
  endpoint; using it on the exchange gives the service provider an actionable code naming the scope
  to request (D31). It is given only to an authenticated caller for a registered resource.
- **Delegation scopes are plain scope strings** with a `token_exchange:` prefix (E1), not Rich
  Authorization Requests (companion §0.2, RFC 9396 rejected).
- **Claims released by the agency's bundle, not the sign-in's scopes** (INT-11): the person approved
  the agency receiving its bundle, not the service provider choosing what the agency learns.
- **No new userinfo behavior for delegated tokens**: they are refused there; the agency reads
  identity through introspection or the SAML attribute statement (companion §6.1 "Why INT-10").
- **Third-party-initiated login is browser-only** and needs no identity-idp change; it is listed so
  the two integration patterns are not confused (companion §16.1).

## Questions this digest answers

- Where do delegation scopes go? In `scope` on the authentication request, as `token_exchange:<application value>`.
- Which `sub` does the agency get? Its agency-level pairwise identifier, identical to a direct sign-in (D35).
- Why does introspection use userinfo claim names? So the agency's existing code consumes delegated identity unchanged (INT-10).
- Is `jti` really required for `private_key_jwt`? Yes (§9), and single-use here (RFC 7523 digest).
- Does the exchange return an `id_token`? Never (EXC-5).
- What does `consent_required` on the exchange mean? Start a sign-in requesting the scope named in `error_description` (D31).
- Does Login.gov implement third-party-initiated login? No code change; reference applications only.

## When to fetch the full text

Read §3.1.2.1, §3.1.2.6, §5.1, §5.3 and §9 in full before changing the authorization form,
claim release or client authentication. https://openid.net/specs/openid-connect-core-1_0.html
