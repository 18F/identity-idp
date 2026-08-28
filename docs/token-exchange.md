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
lifetimes match. The minted identity's scope is the broker's scope intersected
with the target SP's own `attribute_bundle` — the target never receives
attributes it isn't already configured to request.

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
  disclosure and must affirmatively check the token-exchange consent box to
  continue to the broker. Consent is **required** for a broker that requests the
  scope: submitting without checking it re-renders the screen with an error and
  proceeds no further. The decision is recorded on the broker identity as
  `token_exchange_consent_at`, set-or-cleared each time so a dropped scope or a
  new proofing session never carries stale consent forward.
- The exchange endpoint mints **only** when the broker identity has a valid
  recorded consent (`ServiceProviderIdentity#token_exchange_consented?`, subject
  to the same one-year `CONSENT_EXPIRATION` as other SP consent). Absent or
  expired consent fails closed with `invalid_grant`.

This reuses login's established model: an SP's accessible attributes are fixed at
onboarding (its `attribute_bundle`), the SP may request a subset per grant, and
the user consents to that release. The token-exchange capability is one more
grant the user accepts, on the same screen, with the same persistence semantics.

## Security model

The exchange is gated by several independent checks; **all** must pass or
nothing is minted:

1. **Subject token is valid and its session is live.** A dead/expired session
   cannot be exchanged.
2. **The broker SP is allow-listed.** Only an SP configured as a token-exchange
   broker may present a subject token for exchange.
3. **The user consented to token exchange** for this broker, and that consent is
   present, unrevoked, and unexpired.
4. **IAL is forwarded, never elevated.** The minted token carries the IAL the
   broker token was actually asserted at. A broker token below IAL2 mints
   nothing; there is no step-up.
5. **Target must be a real, active SP.** Unknown or inactive issuers are
   rejected.
6. **Target must be on the broker's signed allowlist** (below).

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
