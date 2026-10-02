# Broker Token Exchange

login.gov exposes a browser-callable [RFC 8693][rfc8693] token-exchange
endpoint that lets a designated **broker** service provider trade an access
token it already holds for a token bound to another service provider, for the
**same already-authenticated user**, without a client secret.

`POST /api/openid_connect/exchange`

```
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
subject_token=<broker access token>
subject_token_type=urn:ietf:params:oauth:token-type:access_token
audience=<target SP issuer>
```

## What it does

Given a live broker access token, the endpoint mints a fresh access token +
`id_token` for the target SP, reusing the broker's Rails session so token
lifetimes match. Scope narrowing is done in **claim space**: a scope is granted
only when *every* claim it releases is both in the target SP's `attribute_bundle`
and among the claims the broker was itself verified for. This is what stops an
umbrella scope such as `profile` from releasing `birthdate` to a target whose
bundle only names `first_name` — the target never receives a claim it isn't
configured to request, and never one the broker wasn't authorized to hold.

Nothing about the endpoint is agency-specific: which SPs may act as brokers is a
login-controlled configuration allowlist, and which targets a given broker may
mint for is the broker's own signed manifest. Both are data, not code.

## What the minted token is (read this)

The result is a **full user access token for the target SP**, structurally
identical to one the user would have received by signing in to that SP directly.

Scope narrowing limits **only the identity claims login.gov releases** (what
`userinfo`/`id_token` will return). It does **not** limit what the token can
*do* at the downstream service: the target SP decides what a valid, user-bound
token authorizes in its own APIs, and that is entirely outside login.gov's
control. Treat the minted token as a **full downstream credential for that
user**, not a scoped-down one.

Because of this, the real containment is *which targets can be minted for at
all* (the signed allowlist), *that the user was genuinely proofed* (IAL
forwarding), and *that the user consented to token exchange* (below) — not the
scope string. The scope/attribute narrowing is defense-in-depth on released
claims, nothing more.

## User consent — the token-exchange grant

Token exchange is a **user-consented capability**, surfaced through login's
existing OIDC consent (grant) flow rather than granted silently.

- A broker SP requests the `token_exchange` scope in its authorization request.
  The scope is only honored if the SP is an allow-listed broker
  (`ServiceProvider#token_exchange_broker_allowed?`); otherwise the authorization
  is rejected like any other unauthorized scope.
- Because it is an IAL2-gated scope, it is only grantable in an identity-proofed
  context — consistent with the exchange itself requiring IAL2.
- On the agency handoff (completions) screen the user sees a plain-language
  disclosure and must choose the **breadth of the grant** before continuing to
  the broker. A choice is **required**; submitting without one re-renders the
  screen with an error. The options are:
  - **All services the broker currently offers** — covers exactly the targets on
    the broker's manifest at the moment of consent. Each is snapshotted as its
    own grant row, so a target the broker adds *later* is **not** covered.
  - **All services now or added in the next 12 months** — additionally covers
    targets the broker adds during the grant period.
  - **Only the services I choose** — a collapsed-by-default list of the broker's
    reachable applications (manifest ∩ active ∩ opted-in to this broker); the
    user picks one or more. At least one is required for this option.
- Grants are stored in `token_exchange_grants`, **one row per (user, broker,
  target)** with its own `granted_at` / `expires_at` (12 months) / `revoked_at`,
  so every application the user authorized is independently recorded and
  expirable. An all-targets row uses the `*` sentinel; `includes_future`
  distinguishes the two "all" choices. Re-submitting the screen replaces the
  prior grants for that broker, so a changed decision never leaves stale rows.
- The exchange endpoint mints **only** when the user holds an active grant that
  **covers the requested target** (`TokenExchangeGrant.authorizes?`) **and** the
  subject token being presented was itself issued with the `token_exchange`
  scope. Consent travels with the grant it was given for: a later broker
  authorization that dropped the scope cannot reuse an earlier grant. A target
  outside the grant fails with `invalid_target`; a broker with no grant at all
  fails with `invalid_request`.

This reuses login's established model: an SP's accessible attributes are fixed at
onboarding (its `attribute_bundle`), the SP may request a subset per grant, and
the user consents to that release. The token-exchange capability is one more
grant the user accepts, on the same screen, with the same persistence semantics.

## Security model

The exchange is gated by several independent checks; **all** must pass or
nothing is minted:

1. **Subject token is valid and its session is live.** A dead/expired session
   cannot be exchanged.
2. **The broker SP is allow-listed and active.** Only an active SP configured
   as a token-exchange broker may present a subject token for exchange.
3. **The user consented to token exchange** for this broker, that consent is
   present, unrevoked, and unexpired, and the presented token carries the
   `token_exchange` scope.
4. **IAL is forwarded, never elevated.** The minted token carries the IAL the
   broker token was actually asserted at. A broker token below IAL2 mints
   nothing; there is no step-up.
5. **Target must be a real, active SP entitled to identity proofing.** Unknown,
   inactive, or auth-only (IAL1) issuers are rejected -- an IAL2 assertion is
   never released to an SP that could not request one itself.
6. **Target must be on the broker's signed allowlist** (below).
7. **Target must have opted in to the broker.** The target SP allow-lists the
   broker issuer in its own configuration (`allowed_token_exchange_brokers`, set
   in the partner management portal and synced to login). A broker can never mint
   for a target that has not agreed to accept it — this is the target side's
   independent consent, complementing the broker's manifest (which targets *it*
   is willing to reach).
8. **Target connection not revoked, not held by another live session.** An
   exchange never silently revives a target connection the user explicitly
   disconnected, and never hijacks a target identity bound to a different,
   still-live session. Re-exchanging within the same broker session rotates the
   token. The minted identity carries no redeemable authorization code.

### Signed, broker-controlled allowlist

The set of targets a broker may exchange for is **not** hardcoded in login.gov.
Each broker publishes a signed manifest at a configured URL; login.gov fetches
and verifies it, and only issuers it lists may be minted for. This lets the
broker constrain and revoke its own reach without a login.gov deploy.

The manifest is a compact JWS (a signed JWT). login.gov trusts it only when:

- the signature verifies as **RS256** against a **pre-configured public key**
  selected by the JWS header `kid` (keys are configured per broker; `alg` is
  pinned, so `alg:none`/HS confusion is rejected),
- `iss` equals the broker we're resolving,
- `aud` equals login.gov's own issuer (a manifest can't be replayed at another
  relying party),
- `exp`/`nbf` are valid (60s clock-skew leeway).

### Caching and revocation

A verified manifest is cached for at most **`min(manifest exp, 15 min)`**. On
expiry login.gov refetches (conditional GET; a `304 Not Modified` re-affirms the
cached list). If the broker is unreachable past that window, login.gov **fails
closed** — it returns an empty allowlist rather than serving a stale, possibly
revoked one. So a broker's revocation always takes effect within the cache
window even if its manifest host is down.

## Billing and fraud signals go to the target

A minted token is a credential the **target** relying party will act on, so the
target — not the broker — is treated as the party receiving an authentication,
exactly as if the user had completed a direct sign-in there.

- **Billing.** Each successful mint writes an `SpReturnLog` row for the
  **target issuer**, with the same IAL and profile attribution the direct
  sign-in path records. It is billable once per (user, target, broker session);
  a repeated exchange within the same session only rotates the token and is
  recorded as non-billable, mirroring the per-session dedupe of the direct path.
  The broker is never billed for the target's return.
- **Fraud / Attempts API.** Each successful mint delivers a
  `token-exchange-login-completed` event to the **target's** Attempts API stream
  (only when the target has the Attempts API enabled). The tracker is built for
  the target explicitly: it encrypts to the target's key and writes under the
  target's issuer, so nothing about this return reaches the broker's stream. The
  event carries `broker_issuer` so the target can see it was brokered and by
  whom — the same fact the id_token's `act` claim conveys. Because the exchange
  is a server-to-server call from the broker's backend, the inbound request's IP,
  user agent and cookies describe the broker's infrastructure, not the user's
  device; they are deliberately **not** forwarded, and the event's session
  identifier is an opaque hash, never the IdP session id.

## RFC 8693 conformance notes

- **Delegation, not impersonation.** The exchange is modelled as delegation:
  the broker acts on behalf of the user at the target. The issued `id_token`
  therefore carries an RFC 8693 §4.1 `act` (actor) claim naming the broker,
  `{"act": {"sub": "<broker issuer>"}}`. A target can tell a brokered token
  apart from a direct sign-in and apply policy accordingly. (`exchanged_from`
  in the JSON response conveys the same fact to the broker; only `act` reaches
  the target.)
- **No `c_hash`.** An exchange has no authorization code, so the issued
  `id_token` omits `c_hash`. `at_hash` is present as usual.
- **Request parameters.** `grant_type`, `subject_token`, `subject_token_type`
  are required. `audience` selects the target. `requested_token_type` is
  optional; when supplied it must be the access-token URN (the only type
  issued) or the request fails with `invalid_request`. `scope`, when supplied,
  further narrows the issued scope (it can never widen it). `actor_token` is not
  accepted; the acting party is always the presenting broker.
- **Response.** `access_token`, `issued_token_type`, and `token_type` are always
  present; `scope` is always returned because the issued scope is narrowed;
  `expires_in` is included. No refresh token is issued.
- **Errors (§2.2.2).** A subject token that is invalid or unacceptable under
  policy (unknown, expired session, broker not onboarded, no user consent,
  insufficient IAL) returns `invalid_request`. A target that cannot be issued
  for (not on the manifest, unknown/inactive, has not opted in to the broker,
  or held by another live session) returns `invalid_target`. An unsupported
  `grant_type` returns `unsupported_grant_type`. All errors are HTTP 400 with an
  `error_description`.

## Configuration

Per-broker, in `IdentityConfig`:

- `token_exchange_enabled` — master switch for the capability.
- `token_exchange_service_providers` — JSON array of issuers allowed to act as
  brokers (the login-controlled onboarding allowlist).
- `token_exchange_manifest_urls` — `{ "<broker issuer>": "<https manifest URL>" }`
- `token_exchange_manifest_public_keys` —
  `{ "<broker issuer>": { "<kid>": "<PEM public key>" } }`

A broker with no configured URL or key can exchange for nothing. Plain `http`
is permitted only for loopback hosts (local development).

[rfc8693]: https://datatracker.ietf.org/doc/html/rfc8693
