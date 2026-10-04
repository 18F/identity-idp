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
mint for is decided by each target's own opt-in. Both are data, not code.

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
all* (each target's own opt-in to the broker), *that the user was genuinely
proofed* (IAL forwarding), and *that the user consented to token exchange*
(below) — not the scope string. The scope/attribute narrowing is defense-in-depth on released
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
  disclosure and may choose how the broker is allowed to act for them. Consent
  is **optional** — declining still completes the broker's own sign-in — and
  nothing is pre-checked. The options are:
  - **Allow the broker to act on your behalf across all federal agencies linked
    to your account** — covers every application the user has *already*
    connected (a live identity) that has opted in to the broker. This is
    materialized as **one grant row per application**, never a wildcard.
  - **Automatically enroll new agencies you connect** (dependent on the above
    when the user has linked agencies; offered on its own when they have none)
    — a per-broker setting. When the user later connects a new application that
    has opted in to the broker, its grant is created then, but stamped with the
    time auto-enrollment was **originally** consented to, not the time of first
    use.
  - **— OR — allow access only for the following agencies:** a client-side
    paginated list of the user's linked, opted-in applications grouped by
    agency; the user picks any number.
- Grants live in `token_exchange_grants`, **one row per (user, broker, target)**
  with its own `granted_at` / `expires_at` (12 months) / `revoked_at`, so every
  application has an independently recorded, revocable, expirable timestamp and
  later per-application toggles never have to fight an overriding "all" state.
  Auto-enrollment lives in `token_exchange_broker_settings` as
  `auto_enroll_granted_at` / `auto_enroll_revoked_at`. Re-submitting the screen
  revokes (not deletes) applications the user no longer chose, preserving the
  audit trail.
- On the **account page** (Connected services), each broker shows a toggle per
  linked application and an auto-enroll toggle. Turning a toggle on opens a
  consent modal first; turning it off applies immediately. Each toggle is its own
  grant row or the per-broker setting, so the account page and the handoff
  screen read and write the same state.
- The exchange endpoint mints **only** when the user holds an active grant for
  **the requested target** (`TokenExchangeGrant.authorizes?`) **and** the subject
  token being presented was itself issued with the `token_exchange` scope.
  Consent travels with the grant it was given for: a later broker authorization
  that dropped the scope cannot reuse an earlier grant. A target outside the
  grant fails with `invalid_target`; a broker with no grant at all fails with
  `invalid_request`.

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
6. **Target must have opted in to the broker.** The target SP allow-lists the
   broker issuer in its own configuration (`allowed_token_exchange_brokers`, set
   in the partner management portal and synced to login). A broker can never mint
   for a target that has not agreed to accept it. This is the sole source of a
   broker's reach: there is no broker-asserted allowlist to maintain, because a
   broker simply never requests a target it does not support, and a target it
   does request must have opted in. The set of opted-in targets is also what
   the consent screen lists for the user.
7. **Target connection not revoked, not held by another live session.** An
   exchange never silently revives a target connection the user explicitly
   disconnected, and never hijacks a target identity bound to a different,
   still-live session. Re-exchanging within the same broker session rotates the
   token. The minted identity carries no redeemable authorization code.

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
  for (unknown/inactive, has not opted in to the broker, not covered by the user's grant,
  or held by another live session) returns `invalid_target`. An unsupported
  `grant_type` returns `unsupported_grant_type`. All errors are HTTP 400 with an
  `error_description`.

## Configuration

Per-broker, in `IdentityConfig`:

- `token_exchange_enabled` — master switch for the capability.
- `token_exchange_service_providers` — JSON array of issuers allowed to act as
  brokers (the login-controlled onboarding allowlist).

Per-target, in the partner management portal (synced to `service_providers`):

- `allowed_token_exchange_brokers` — the broker issuers this SP accepts
  exchanged tokens from. A broker no target has opted in to can exchange for
  nothing.

[rfc8693]: https://datatracker.ietf.org/doc/html/rfc8693
