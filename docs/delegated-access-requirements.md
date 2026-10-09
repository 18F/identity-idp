# Delegated Access for Login.gov — Requirements

**Audience:** maintainers of `18F/identity-idp`
**Status:** Draft for review
**Baseline:** `identity-idp` `main` as of 2026-09-04 (`48a1ff3e3f`)

> Implementation note (2026-09-28): the baseline commit does not boot under `identity-hostdata` 4.4.2 because
> `lib/identity_config.rb` passes the type of `lexisnexis_threatmetrix_hybrid_handoff_policy` positionally
> (`config.add(:key, :string, ...)`) where `#add` takes `type:` as a keyword. The fix is one line and is the first
> commit on every implementation branch.

---

## 0. How to read this document

This document specifies a new capability for Login.gov: letting a **service provider** (a service the user
signs in to) obtain tokens that let it call **other agencies' APIs** on the user's behalf, with
the user's explicit consent and under Login.gov's control. It covers the exchange endpoint itself
(§5) and the six areas that make it safe to ship: consent (§4), enforcement (§6), refresh and
revocation (§7), fraud signals (§8), billing (§9), and the reference implementations partners
will test against (§14). A seventh item (§15) adds SAML assertions as an issued token type; it
depends on §5 and can be scheduled separately.

Examples use placeholders in `[brackets]` — `[agency]`, `[service-provider-name]`,
`[agency-api]`, `[agency-api-scope]` — rather than real agencies or APIs. The design does not
depend on what any particular API does; it depends only on the standards cited.

It is written for developers. Each requirement has:

- an **ID** you can reference in issues and PRs (for example `CON-3`),
- a plain statement using **MUST**, **SHOULD** and **MAY** as defined in RFC 2119 and RFC 8174,
- **Why** — the reason the requirement exists, so you don't have to infer it,
- **Where** — the files that change, and
- **How** — enough detail, and code where useful, to start work.

Code snippets are illustrative. They show shape and intent; names and exact placement are the
implementer's call. All line references are to the baseline commit above.

### 0.1 Terms

| Term | Meaning |
|---|---|
| **User** | The person who signs in to Login.gov. |
| **Service provider (SP)** | The application the user signs in to, which then acts for the user at other agencies' APIs. This is Login.gov's long-standing term for what OAuth 2.0 (RFC 6749) calls the *client*, OpenID Connect calls the *relying party*, and RFC 8693 calls the *actor* (the `act` claim). Spec terms appear in parentheses where the protocol uses them (`client_id`, `client_assertion`, `act`). |
| **Target agency** | An agency whose API the service provider wants to call on the user's behalf. |
| **Agency SP** | The target agency's own service provider record in Login.gov. It owns resource servers and supplies the agency's `agency_id` (for the user's `sub`), attribute bundle and certificates. Used only when the record itself matters; otherwise the target is called the *resource server*. |
| **Resource server** | A specific target-agency API, registered with Login.gov. The OAuth term for "the thing the token is for". |
| **Delegation scope** | A Login.gov-defined value, `token_exchange:<name>`, that stands for one resource server (or one part of it) and is what the user consents to. |
| **Grant** | A record that the user approved one delegation scope for one service provider. |
| **Delegated token** | An access token Login.gov issues to the service provider for one resource server, by exchanging the service provider's own token. |
| **Exchange** | The RFC 8693 operation that turns the service provider's token into a delegated token. |
| **Introspection** | The RFC 7662 operation a resource server uses to ask Login.gov whether a token is valid and what it is for. |

### 0.2 Standards this document relies on

Wherever a standard covers a behavior, this document requires the standard's behavior rather
than inventing one. Read the cited section when implementing.

| Standard | What it is used for here |
|---|---|
| [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749) OAuth 2.0 Authorization Framework | Base protocol: scopes, `invalid_scope`, refresh grant (§6), error format (§5.2). |
| [RFC 6750](https://www.rfc-editor.org/rfc/rfc6750) Bearer Token Usage | How tokens are presented to APIs. |
| [RFC 7009](https://www.rfc-editor.org/rfc/rfc7009) Token Revocation | Endpoint for a service provider to revoke a refresh token. |
| [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519) JSON Web Token, [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725) JWT Best Current Practices | Claims and validation rules for every JWT here. |
| [RFC 7523](https://www.rfc-editor.org/rfc/rfc7523) JWT Profile for Client Authentication (`private_key_jwt`) | How service providers and resource servers prove who they are. Login.gov already uses this at `/api/openid_connect/token`. |
| [RFC 7662](https://www.rfc-editor.org/rfc/rfc7662) Token Introspection | The endpoint resource servers call to validate delegated tokens. |
| [RFC 8693](https://www.rfc-editor.org/rfc/rfc8693) Token Exchange | The exchange request/response, the `act` (actor) claim, `invalid_target`. |
| [RFC 8707](https://www.rfc-editor.org/rfc/rfc8707) Resource Indicators | The `resource` parameter naming which API a token is for. |
| [RFC 9449](https://www.rfc-editor.org/rfc/rfc9449) DPoP | Sender-constrained delegated tokens: binding a token to a key the service provider holds, so a stolen token is useless (§5.1 EXC-9, §6.1 INT-4, §7.1 REF-3, Appendix C). Mandatory per resource server when the agency requires it. |
| [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700) OAuth 2.0 Security Best Current Practice | Refresh-token rotation and reuse detection (§4.14), sender-constraining, no tokens in browsers. |
| [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html) | Existing sign-in; `sub`, consent, `id_token` rules. |
| [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html), [RFC 8414](https://www.rfc-editor.org/rfc/rfc8414) | Advertising the new endpoints and grant types. |
| [RFC 8417](https://www.rfc-editor.org/rfc/rfc8417) Security Event Token, [RFC 8936](https://www.rfc-editor.org/rfc/rfc8936) Poll-Based SET Delivery, [OpenID Shared Signals Framework](https://openid.net/specs/openid-sharedsignals-framework-1_0.html) | The Attempts API's existing event format and delivery. |
| [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) §4.2.3 | AAL2 reauthentication limit (12 hours), which bounds refresh-token life. |
| [NIST SP 800-63C](https://pages.nist.gov/800-63-4/sp800-63c.html) | Federation and the requirement for user consent before attribute release. |

Two standards were considered and **not** used:

- **RFC 9068 (JWT access tokens).** Login.gov access tokens are opaque random strings looked up
  in the database. Keeping them opaque means a resource server *must* ask Login.gov before
  trusting a token, which is exactly the control this design wants. Self-contained JWTs would
  let an API skip that check and would need a separate revocation mechanism.
- **RFC 9396 (Rich Authorization Requests).** It could express per-API consent, but Login.gov's
  consent screen, scope parsing and `requested_attributes` all key on scope strings. Named
  scopes fit the existing code with far less change.

---

## 1. Goals and non-goals

### 1.1 Goal

Allow a service provider to act on a user's behalf at agency APIs using Login.gov identity, **without
weakening any guarantee that direct sign-in gives today**:

1. The **user** chooses and understands each delegation, and can review and revoke it.
2. **Login.gov**, not the service provider, decides which API a token is good for and can revoke it.
3. **Agencies** keep the fraud signals (Attempts API) they rely on.
4. Every delegated access is **billed and measurable** the same way a direct one is.
5. A service provider can keep working for the user for a **bounded time** without holding anything the
   user didn't approve.
6. **Partners can see it working before they build.** Login.gov ships reference
   implementations of both partner roles — a service provider and an agency resource API — and an
   end-to-end test harness, so agencies can run the whole flow against the sandbox and copy
   working code.

### 1.2 Non-goals

- Refresh tokens for ordinary (non-delegated) sign-ins. The machinery here could later serve
  them, but that is a separate decision.
- Letting a delegated token be exchanged again (chained delegation).
- Step-up or elevation: a delegated token never carries a higher IAL or AAL than the service provider's
  sign-in.
- Browser-callable exchange. The exchange and refresh grant types require a signed client
  assertion, so they can only be used from a server that holds the service provider's key (§2.3).

---

## 2. End-to-end flow

### 2.1 Actors

```
 User ──(browser)──► Service provider web app ──(server)──► Login.gov
                          │                          ▲
                          │ delegated token          │ introspect / refresh
                          ▼                          │
                     Agency API ─────────────────────┘
                          │
                          └──── polls Attempts API ──► Login.gov
```

### 2.2 Happy path

1. **Onboarding.** The agency registers its API with Login.gov as a *resource server* and
   defines one or more *delegation scopes* with plain-language descriptions. The service provider is
   approved for delegation and provides content describing who it is. (§3)
2. **Authorize.** The service provider redirects the user to `/openid_connect/authorize` with
   `scope=openid email token_exchange:[agency-api-scope-a] token_exchange:[agency-api-scope-b]`. (§4)
3. **Sign in and consent.** The user signs in. On Login.gov's existing consent screen (the
   *completions* screen at `/sign_up/completed`, §4.3) they see who the service provider
   is and one checkbox per requested API, each explaining what it does. They approve some, all
   or none, and choose whether Login.gov should remember the choice for a year. (§4)
4. **Handoff.** Login.gov redirects to the service provider with an authorization code. The token
   response lists only the approved `token_exchange:*` scopes. (§4.6)
5. **Exchange.** The service provider's server calls the existing token endpoint,
   `POST /api/openid_connect/token`, with `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`, its access
   token, `resource=<API identifier>`, and a signed client assertion. Login.gov returns a
   15-minute delegated access token and a 12-hour refresh token, bound to that one API. (§5, §7)
6. **API call.** The service provider calls the agency API with the delegated token.
7. **Introspection.** The agency API calls `POST /api/openid_connect/introspect` with the token
   and its own signed client assertion. Login.gov answers `active: true` with `sub`, `scope`,
   `act` and `delegation_id`, or `active: false`. The API allows or refuses the call. (§6)
8. **Fraud signals.** At step 3, Login.gov delivers the user's sign-in and consent events to
   each approved agency through the Attempts API, tagged with the same `delegation_id`. (§8)
9. **Billing.** At step 5, Login.gov records a billing row for the agency, marked as delegated
   access. (§9)
10. **Refresh.** The service provider refreshes the access token every 15 minutes for up to 12 hours,
    then must send the user back through steps 2–5. (§7)
11. **Review.** The user sees every remembered delegation, with time remaining, under
    *Account → Delegated access*, and can revoke any of them. (§4.7)

### 2.3 Design decisions that shape everything below

- **The exchange is server-to-server.** Public (browser) clients cannot keep a secret, so a
  token in a browser is exposed to any script on the page (XSS, a compromised dependency, an
  extension). If such a token could be exchanged for other agencies' tokens, one service provider's XSS
  bug would compromise every target agency. Requiring `private_key_jwt` (RFC 7523) means a
  stolen token is useless without the service provider's private key. (RFC 9700 §2.1, §4.)
- **Tokens stay opaque, and resource servers introspect.** See §0.2. This keeps revocation
  instant and makes Login.gov the decision point.
- **One token per API.** A delegated token names exactly one resource server in `aud`. A leak
  exposes one API, not the agency.
- **Login.gov defines the targets.** Service providers request from a fixed list; they cannot add to it.
- **Consent is per API, with the user in control of persistence.**

---

## 3. Onboarding data model

This section defines the records everything else refers to.

### 3.1 Requirements

| ID | Requirement |
|---|---|
| **ONB-1** | Login.gov MUST maintain a list of **service providers approved for delegation**. Only a service provider approved for delegation may request a `token_exchange:*` scope or call the exchange endpoint. |
| **ONB-2** | Login.gov MUST maintain a registry of **resource servers**: each target API, with a stable identifier, the agency SP that owns it, and one or more public keys for client authentication. |
| **ONB-3** | Login.gov MUST maintain a registry of **delegation scopes**: each `token_exchange:<name>` value, the resource server it belongs to, and the localized content shown to the user. |
| **ONB-4** | Service providers MUST supply, and Login.gov MUST approve, content describing who the service provider is. |
| **ONB-5** | All of the above MUST be managed through Login.gov's existing SP onboarding pipeline (`config/service_providers.yml` + `ServiceProviderSeeder`, and `ServiceProviderUpdater` in lower environments), not through ad-hoc edits or application config. |
| **ONB-6** | Every new database column MUST carry a `comment: 'sensitive=true|false'` as enforced by `lib/tasks/column_comment_checker.rake` and `spec/db/schema_spec.rb`. |
| **ONB-7** | The seeder and updater MUST upsert resource servers by `identifier` and scopes by `scope_value`, and the updater MUST **deactivate** (not delete) children absent from a Dashboard payload. |
| **ONB-8** | Agency-authored `description` MUST be stored as the completion of the sentence stem "This lets the service ___", and `display_name` SHOULD start with a verb; the consent screen supplies the stem. |

**Why ONB-7.** Grants and tokens reference scopes and resource servers by id; deleting a child would orphan
them or cascade into revoking access an agency only meant to pause. `active: false` already carries the
kill-switch meaning everywhere else in the design, so it is the right outcome for "no longer listed".

**Why ONB-8.** The agency form asks for the completion, and the screen renders the stem; storing the full
sentence made it appear twice ("This lets the service This lets the service…") the first time the
screen was rendered with fixture data.

**Why ONB-5.** The seeder and updater are the reviewed, auditable path for SP configuration.
Putting service provider allowlists or keys in `application.yml` would bypass that review, and the
Dashboard (which the updater reads) is where partner teams already manage SP records.

### 3.2 Tables

**`service_providers` — new columns**

| Column | Type | Comment | Purpose |
|---|---|---|---|
| `token_exchange_enabled_sp` | boolean, default false | sensitive=false | ONB-1. This SP is approved to request delegation (ONB-1). |
| `token_exchange_target` | boolean, default false | sensitive=false | This SP's agency may own resource servers. |
| `delegation_operator_legal_name` | string | sensitive=false | ONB-4 |
| `delegation_operator_type` | string (enum: `federal`, `state_local`, `contractor`, `non_government`) | sensitive=false | ONB-4 |
| `delegation_service_description` | jsonb (locale → text) | sensitive=false | ONB-4 |
| `delegation_data_handling_statement` | jsonb (locale → text) | sensitive=false | ONB-4 |
| `delegation_privacy_policy_url` | text | sensitive=false | ONB-4, required for service providers |
| `delegation_terms_of_service_url` | text | sensitive=false | ONB-4, optional |
| `delegation_support_contact` | text | sensitive=false | ONB-4 |
| `delegation_uses_ai` | boolean, default false | sensitive=false | ONB-4. Whether the service uses AI or automated decision-making on user data; drives the consent screen's "Uses AI" row |
| `delegation_ai_description` | jsonb (locale → text) | sensitive=false | ONB-4. Completion of "It uses AI to ___", shown only when `delegation_uses_ai` is true |
| `sp_content_version` | integer, default 1 | sensitive=false | Incremented whenever service provider content changes; see CON-9 |

**`token_exchange_resource_servers` — new table**

| Column | Type | Comment | Purpose |
|---|---|---|---|
| `id` | bigint | | |
| `identifier` | string, unique, not null | sensitive=false | The API's URI, e.g. `https://[agency-api]`. Becomes the token's `aud` and the API's `client_id` at introspection. |
| `service_provider_id` | FK → `service_providers` | sensitive=false | Owning agency SP. Its `agency_id` determines the user's `sub`; its `attribute_bundle` bounds released attributes. |
| `attempts_service_provider_id` | FK → `service_providers`, nullable | sensitive=false | The SP whose Attempts API credentials receive events (§8). Defaults to `service_provider_id`. |
| `billing_issuer` | string, nullable | sensitive=false | Issuer whose IAA is billed (§9). Defaults to the owning SP's issuer. |
| `certs` | string[] | sensitive=false | PEM certificates, same format and rotation as `service_providers.certs`. |
| `active` | boolean, default true | sensitive=false | Kill switch. |
| timestamps | | sensitive=false | |

**`token_exchange_scopes` — new table**

| Column | Type | Comment | Purpose |
|---|---|---|---|
| `id` | bigint | | |
| `scope_value` | string, unique, not null | sensitive=false | The part after `token_exchange:`. Format `[a-z0-9_]{1,64}`. |
| `resource_server_id` | FK → `token_exchange_resource_servers` | sensitive=false | |
| `display_name` | jsonb (locale → text) | sensitive=false | e.g. "[Agency] [API display name]" |
| `description` | jsonb (locale → text) | sensitive=false | What the API does and what the service provider can do with it |
| `data_provided` | jsonb (locale → text[]) | sensitive=false | Data categories the API returns |
| `access_type` | string (enum: `read`, `read_write`) | sensitive=false | Shown to the user |
| `learn_more_url` | text, nullable | sensitive=false | The agency's "learn more" page for this capability, linked from its consent card (agency form 3.4) |
| `content_version` | integer, default 1 | sensitive=false | Incremented whenever user-facing content changes |
| `active` | boolean, default true | sensitive=false | Kill switch |
| `approved_at`, `approved_by` | datetime, string | sensitive=false | Login.gov content approval |
| timestamps | | sensitive=false | |

**Localized content rules.** Every jsonb content column MUST have an `en` value; `es`, `fr` and
`zh` SHOULD be present. Rendering MUST fall back to `en` when the current locale is missing.

> Note: the existing `service_providers.help_text` column is jsonb keyed by locale, but it is
> rendered as *sanitized HTML* (`app/views/shared/_sp_alert.html.erb`) and has no `en`
> fallback. Reuse its storage shape only. Delegation content is rendered as escaped plain text
> (CON-8).

### 3.3 Where and how

- **Migrations:** `db/primary_migrate/<timestamp>_create_token_exchange_resource_servers.rb`,
  `..._create_token_exchange_scopes.rb`, `..._add_token_exchange_columns_to_service_providers.rb`
  (`ActiveRecord::Migration[8.1]`).
- **Models:** `app/models/token_exchange_resource_server.rb`, `app/models/token_exchange_scope.rb`;
  associations on `app/models/service_provider.rb`.
- **Seeder:** `app/services/service_provider_seeder.rb#write_service_provider` maps YAML keys to
  columns on one SP row. Extend it to accept nested `token_exchange_resource_servers:` and
  `token_exchange_scopes:` arrays and upsert child rows by `identifier` / `scope_value`.
  Mirror the change in `app/services/service_provider_updater.rb`.

  *As built:* both upsert children by natural key and are idempotent. The updater **deactivates**
  children missing from a Dashboard payload rather than deleting them, so existing grants and tokens
  keep their foreign keys and the kill-switch semantics of `active: false` apply. Resource server
  `certs` use the same `certs/sp/<name>.crt` lookup as SP certs; a missing file is skipped, which lets
  the fixture reference a certificate that each developer generates locally and never commits.
  Agency-authored `description` text stores only the completion of the sentence stem
  "This lets the service ___" (the screen supplies the stem), otherwise the stem appears twice.

Example YAML for `config/service_providers.yml`:

```yaml
# Placeholders in [brackets] are filled in per partner. Nothing here assumes what the API does.
'urn:gov:gsa:openidconnect:sp:[target-agency]:[service-provider-name]':
  friendly_name: '[Agency SP display name]'
  agency_id: [agency-id]
  ial: 2
  token_exchange_target: true
  token_exchange_resource_servers:
    - identifier: 'https://[agency-api]'
      certs: ['[agency-api-cert-name]']
      token_exchange_scopes:
        - scope_value: '[agency-api-scope]'
          access_type: 'read'            # or read_write
          display_name:
            en: '[Agency] [API display name]'
            es: '[Spanish display name]'
          description:
            en: '[What the API does and what the service may do with it on your behalf.]'
          data_provided:
            en: ['[Data category 1]', '[Data category 2]']
```

---

### 3.4 Amendments of 2026-10-09 (`login-delegated-access`)

Decided in the interview on the first implementation feature; rationale in Appendix E rows E37–E45 and in the functional requirements, Appendix D. Where a row below conflicts with §3.1–§3.3, this subsection governs.

| ID | Requirement |
|---|---|
| **ONB-2** (amend) | The registry unit is the **application**: an agency-owned `service_providers` row with `delegation_application: true`, `delegation_scope_value` (unique, `[a-z0-9_]{1,64}`), localized consent content (`delegation_display_name`, `delegation_description`, `delegation_data_provided`), `delegation_access_type`, `delegation_learn_more_url`, `consent_content_version`, `consent_material_version`, `consent_approved_at`/`consent_approved_by`, and `allowed_delegation_service_providers` (string array; empty means any service provider approved for delegation). `token_exchange_resource_servers` rows are the application's API URLs and keep their columns (identifier, `attempts_service_provider_id`, `billing_issuer`, `certs`, `token_format`, `dpop_required`, `active`). |
| **ONB-3** (replace) | There is **one delegation scope per application**, `token_exchange:<delegation_scope_value>`. The `token_exchange_scopes` table is not built; the content ONB-3 described lives on the application row. The consent screen lists the application's resource server identifiers for information. |
| **ONB-10** | `agencies` carries agency-level consent content: localized `delegation_description`, `delegation_learn_more_url`, `consent_content_version`, `consent_material_version`, all nullable or defaulted so agencies without applications are unaffected. |
| **ONB-11** | Every content owner (agency, application, service provider) has two version counters: `*_content_version`, incremented on every edit, and `*_material_version`, set equal to it when the editor marks the edit as material. Grants record the versions they were given under; validity compares them with the material versions (CON-12 as amended). |
| **ONB-12** | Consent content is edited in the partner Dashboard (`identity-dashboard`) and reaches the identity provider through `ServiceProviderUpdater` (lower environments) and the seeder (production). The Dashboard MUST gain the agency, application and service provider fields of ONB-2, ONB-4, ONB-10 and nested `token_exchange_resource_servers` in its API payload. This is a dependency on a separate repository and MUST be stated in the seeder, updater and model comments. Until it is met, `config/delegated_access.localdev.yml` loaded by `rake delegated_access:seed` (which refuses `prod` and `staging`) provides the data for local, review-app and sandbox environments. |
| **ONB-13** | Service provider approval is `service_providers.token_exchange_enabled_sp` only. No application-configuration allow-list of service providers exists; `token_exchange_enabled` remains the single master switch. |
| **ONB-14** | The identifiers, strings, comments and analytics properties inherited from the `sbx-taigrr` branch that say "broker" are renamed to say service provider, and comments describing the exchange as browser-callable or the service provider as a public client of Login.gov are corrected, in the onboarding feature, across the whole branch. |
| **ONB-2** (amend 2026-10-09, D47) | `token_exchange_resource_servers.dpop_required` is dropped by the DPoP feature's migration, together with the seeder and localdev fixture key of that name. Whether a token is bound follows the service provider's client type (EXC-17): public clients always, confidential clients never; an application does not require or waive binding per API. `token_format` stays, informational for now (SAML-3 as amended in §15.8). |

**Why ONB-2/ONB-3 (amend).** People think in terms of the application they use, not the agency and not its individual APIs; one choice per application keeps the screen readable and the scope string meaningful to partners. The URL registry remains so each token is still issued for exactly one API (EXC-1, EXC-4).

**As built, 2026-10-09 (`delegated-access-registry`).** Migrations `20261009100000`–`20261009100400`: agency content on `agencies`; application columns and `allowed_delegation_service_providers` on `service_providers` (the earlier opt-in column dropped); `token_exchange_resource_servers`; service provider approval and content on `service_providers`; `token_exchange_grants` recreated in the (user, service provider, application) shape, `token_exchange_broker_settings` dropped. Models: `TokenExchangeResourceServer`, `TokenExchangeGrant` (`approve!`, `valid_now?`, `revoke!`, version-pair check), `DelegationLocalizedContent`, `ServiceProvider#delegation_application?`/`#accepts_delegation_from?`/`#delegation_scope`/`#delegation_service_provider?`, `Agency` content accessors, `DelegationApplications` (registry query). Seeder and updater write applications and nested `token_exchange_resource_servers`; `DelegatedAccessSeeder` and `rake delegated_access:seed` load `config/delegated_access.localdev.yml` outside prod and staging. Configuration keys of §10 are added by the feature that reads each (E46).

**Why ONB-11.** Content will be edited regularly; re-asking every person on every wording fix would make remembered consent meaningless, while never re-asking would let a material change slip past consent. The editor decides which it is, and the decision is recorded in the version pair.

---

## 4. Authorization and consent

### 4.1 Requirements — requesting delegation

| ID | Requirement |
|---|---|
| **CON-1** | A service provider requests delegation by including one or more `token_exchange:<scope_value>` values in the OIDC `scope` parameter. |
| **CON-2** | Login.gov MUST reject the authorization request with `error=invalid_scope` (RFC 6749 §4.1.2.1) if any `token_exchange:` value does not match an active `token_exchange_scopes` row whose resource server and owning SP are active, or if the requesting SP is not a service provider approved for delegation. |
| **CON-3** | Rejection under CON-2 MUST apply only to values with the `token_exchange:` prefix. Unknown scopes without that prefix MUST keep today's behavior (silently ignored). |
| **CON-4** | `token_exchange:*` values MUST only be honored on identity-proofed (IAL2 / IALmax) requests. |

**Why CON-3.** Today `OpenidConnectAuthorizeForm#parse_to_values` intersects the requested
scopes with a fixed list and drops anything unknown. Login.gov's own sample relying party
(`identity-oidc-sinatra`) sends values like `sub` and `given_name` that are not valid scopes
and relies on them being ignored. A blanket `invalid_scope` would break existing integrations.

**Why CON-4.** Delegated tokens carry verified identity to other agencies; that only makes sense
for a proofed user, and it keeps the exchange from ever elevating assurance.

### 4.2 Where and how — scope parsing

Scopes are checked against static constants in **three** places. Each needs a dynamic path
for the `token_exchange:` prefix, or DB-defined values are dropped before any validation runs.

1. `app/forms/openid_connect_authorize_form.rb`
   - `#scopes` (line ~292) returns `OpenidConnectAttributeScoper::VALID_SCOPES` or
     `VALID_IAL1_SCOPES`.
   - `#parse_to_values` (line ~168) does `param_value.split(' ') & possible_values`.
2. `app/services/openid_connect_attribute_scoper.rb#parse_scope` (line ~111) — used to compute
   `requested_attributes` for the SP session (`app/models/federated_protocols/oidc.rb`).
3. `SCOPE_ATTRIBUTE_MAP` / `ATTRIBUTE_SCOPES_MAP` in the same file are built at load time.

Suggested shape:

```ruby
# app/services/openid_connect_attribute_scoper.rb
TOKEN_EXCHANGE_PREFIX = 'token_exchange:'

def self.token_exchange_scope?(value)
  value.start_with?(TOKEN_EXCHANGE_PREFIX)
end

def parse_scope(scope)
  values = scope.to_s.split(' ')
  static  = values & VALID_SCOPES
  dynamic = values.select { |v| self.class.token_exchange_scope?(v) }
  static + dynamic   # dynamic values are validated separately (below)
end

def token_exchange_scope_values
  scopes.select { |v| self.class.token_exchange_scope?(v) }
        .map { |v| v.delete_prefix(TOKEN_EXCHANGE_PREFIX) }
end
```

```ruby
# app/forms/openid_connect_authorize_form.rb
validate :validate_token_exchange_scopes

def validate_token_exchange_scopes
  requested = OpenidConnectAttributeScoper.new(raw_scope).token_exchange_scope_values
  return if requested.empty?

  unless service_provider&.token_exchange_enabled_sp? && identity_proofing_requested_or_default?
    return errors.add(:scope, t('openid_connect.authorization.errors.unauthorized_scope'),
                      type: :unauthorized_scope)
  end

  known = TokenExchangeScope.active.where(scope_value: requested).pluck(:scope_value)
  unknown = requested - known
  return if unknown.empty?

  errors.add(:scope, t('openid_connect.authorization.errors.unknown_delegation_scope',
                       scopes: unknown.join(', ')),
             type: :invalid_scope)
end
```

Do **not** add `token_exchange:*` values to `VALID_SCOPES`; they are not attribute scopes and
must not flow into `verified_attributes` (CON-6).

**As built, 2026-10-09 (`delegated-access-consent`).** The shape above with the decided names:
`OpenidConnectAttributeScoper::DELEGATION_SCOPE_PREFIX` (`ServiceProvider::DELEGATION_SCOPE_PREFIX`),
`.delegation_scope?`, `#delegation_scope_values`, `#delegation_requested?`; in the authorize form,
`#parse_scope_param` keeps prefixed values and `#validate_delegation_scopes` adds
`delegation_not_allowed` (service provider not approved, or the request is not identity-verified;
CON-22) or `unknown_delegation_scope` (values not in `DelegationApplications.accepting(client_id)`,
which already excludes inactive applications, inactive agencies and applications whose allow-list
excludes the caller; CON-2 as amended). Both are reported to the service provider as
`error=invalid_scope`. The bare values reach the SP session as
`sp_session[:requested_delegation_scopes]` through `FederatedProtocols::Oidc#requested_delegation_scopes`
(CON-21) and are logged as `delegation_scopes` on the authorize analytics event.

### 4.3 Requirements — the consent screen

**The screen this section builds on.** Login.gov already has a consent screen: the *completions*
(or "agency handoff") screen at `/sign_up/completed`, rendered by
`SignUp::CompletionsController` and `app/views/sign_up/completions/show.html.erb`. Every OIDC and
SAML sign-in is redirected to it when `VerifySpAttributesConcern#needs_completion_screen_reason`
returns a reason (`openid_connect/authorization_controller.rb:44`, `saml_idp_controller.rb:45`):
the user's first connection to this SP (`:new_sp`), newly requested attributes
(`:new_attributes`), reverification, expired consent, or revoked consent. When it returns nil
the screen is skipped and the user goes straight to the SP. Submitting the screen calls
`update_verified_attributes`, which stores every requested attribute on the user's identity
record for that SP. Per-API delegation consent is added to this screen rather than a new one, so
the user sees one consent step, not two.

| ID | Requirement |
|---|---|
| **CON-5** | When a request carries `token_exchange:*` values, the completion ("agency handoff") screen MUST be shown unless every requested value is covered by a *remembered*, unrevoked, current-version grant (CON-10). When it is shown, remembered approvals MUST be pre-checked and every other value — including any the user declined before — MUST be unchecked. |
| **CON-6** | `token_exchange:*` values MUST NOT be written to `identities.verified_attributes`. |
| **CON-7** | The screen MUST show (a) a panel describing the service provider from the ONB-4 content, and (b) one checkbox per requested delegation scope, showing the target agency's name and logo, `display_name`, `description`, `data_provided`, `access_type` and the agency's `learn_more_url`. All checkboxes start unchecked. The user MAY approve any subset, including none. The layout and copy MUST follow the approved consent-screen mockup (`Consent screen mockup/consent-screen.html`): the service provider's logo and a heading naming it, its one-sentence description, an "About this service" card (run by, uses AI, your information, learn more), the requested services grouped by agency with a count, per-card badges "Read only" / "Can make changes", the remember checkbox with its explanation and the account link, and the buttons "Allow selected and continue" and "Cancel and return to <service provider>". |
| **CON-8** | All agency- and service provider-supplied content MUST be rendered HTML-escaped. Content MUST come only from the database, never from the authorization request. |
| **CON-9** | The screen MUST show a "Remember my approvals for 1 year" checkbox, unchecked by default, visible only when at least one delegation is approved. Its help text MUST say the user can review and change these approvals under *Account → Delegated access*, that if unchecked Login.gov will ask again next time, and that anything not approved will be asked about again regardless. |
| **CON-17** | Once the user has submitted the screen for an authorization (approving or declining), it MUST NOT be shown again before that authorization's handoff completes. The implementation records a digest of the authorize URL (`sp_session[:request_url]`) in the user session at submit and skips the delegation reason while it matches. It MUST NOT key on the SP request id: `ServiceProviderRequestHandler` reuses that id when the same service provider authorizes again in one browser session, which would suppress the screen on a later authorization that adds a scope (found by the live end-to-end run). Every authorization carries a fresh `state` and `nonce`, so its URL is unique. |
| **CON-18** | The agency shown for each group of scopes MUST be the agency SP's `Agency#name`, not the agency SP's `friendly_name`. |
| **CON-9a** | A **decline MUST never be remembered.** If a service provider requests a delegation scope the user previously declined, the screen MUST be shown again with that value unchecked, whether or not the user chose to remember their approvals. Only approvals can suppress the screen (CON-5). |

**Why CON-5 and CON-6.** These two requirements exist because of how the existing screen decides
whether to appear. `needs_completion_screen_reason` returns nil — and the screen is skipped —
when every requested attribute is already in the identity's `verified_attributes`, and it stays
skipped until consent expires after `ServiceProviderIdentity::CONSENT_EXPIRATION` (one year).
`update_verified_attributes` writes *all* requested attributes there, whether or not the user
saw them as checkboxes.

The obvious implementation — treat `token_exchange:*` like any other scope, so it lands in
`requested_attributes` and then in `verified_attributes` — would therefore break consent in
three ways on a returning user: the screen would not appear again for a year, a value the user
*declined* would be recorded as verified and count as approved, and a service provider adding a
new target later would only trigger the screen if that exact value was new. CON-5 adds an
explicit reason so the screen appears whenever delegation needs consent; CON-6 keeps delegation
values out of `verified_attributes` so they can never satisfy the existing check by accident.

**Why CON-8.** This is the first time text authored by a partner is rendered on a Login.gov
consent screen. Escaping is the only safe default.

*As built (CON-7):* the agency shown for each group is the agency SP's `Agency#name` (the same
name the account page uses for connected services), not the agency SP's `friendly_name`, so the user
sees the agency rather than one of its applications. The screen loads scopes, resource servers and
agency SPs with one query per table and joins them in memory; ActiveRecord `includes` chains through
three associations tripped the test suite's N+1 detector (Bullet) in both directions.

**Why CON-17.** The completion screen redirects back to the authorize URL to finish the handoff. A
non-remembered approval is not a *remembered* grant, so without this rule the delegation reason fired again
and the screen looped forever. A later authorization has a new request id, so a declined value is still
asked about again (CON-9a).

**Why CON-18.** Users decide by agency, and the account page already names connected services by agency;
an agency may register several SP records whose friendly names mean nothing to the public.

**Why CON-9a.** Users will decline APIs they actually want, because the consent text was unclear
or they were cautious on first sight. Once they see in the service provider what they cannot do,
they will want to try again. A remembered decline would silently block that for a year with no
prompt explaining why. Re-asking costs one screen; a silent block costs the user the feature.
Declines are still *recorded* (CON-14) so Login.gov can report on them, but the record has no
effect on whether the user is asked again.

### 4.4 Where and how — showing the screen

`app/controllers/concerns/verify_sp_attributes_concern.rb`:

```ruby
def needs_completion_screen_reason
  return nil if sp_session[:issuer].blank?
  return nil if sp_session[:request_url].blank?

  sp_session_identity = find_sp_session_identity
  if sp_session_identity.nil?
    :new_sp
  elsif delegation_consent_needed?(sp_session_identity)          # new
    :delegation_requested
  elsif !requested_attributes_verified?(sp_session_identity)
    :new_attributes
  # ... existing branches unchanged
  end
end

def requested_delegation_scopes
  Array(sp_session[:requested_delegation_scopes])   # set at authorize, see 4.2
end

# True when any requested delegation scope lacks a remembered, live, current grant.
def delegation_consent_needed?(identity)
  return false if requested_delegation_scopes.empty?
  covered = TokenExchangeGrant.remembered_and_current_for(identity)
                              .pluck(:scope_value)
  (requested_delegation_scopes - covered).any?
end
```

Once the user has submitted the screen for an authorization (approving or declining), it MUST NOT be shown again before that authorization's handoff completes, or the redirect back to the authorize URL would loop; the implementation records the SP request id (`sp_session[:request_id]`) in the user session at submit and skips the delegation reason while it matches. A later authorization has a new request id, so a declined value is asked about again (CON-9a).

`update_verified_attributes` MUST pass `verified_attributes:` with delegation values removed:

```ruby
verified_attributes: sp_session[:requested_attributes] - requested_delegation_scopes.map { |v| "token_exchange:#{v}" }
```

`app/controllers/sign_up/completions_controller.rb#update` reads the per-scope checkboxes and
the remember flag and writes grants (§4.5). `app/presenters/completions_presenter.rb` exposes
the service provider panel and the list of scope records (loaded by `scope_value`, with `en` fallback).
`app/views/sign_up/completions/show.html.erb` renders them with `<%= %>` (escaped), never
`raw` or `.html_safe`.

**As built, 2026-10-09 (`delegated-access-consent`).** `delegation_consent_needed?` is the reason
`:delegation_requested`, checked after the existing reasons (a new service provider or new attributes
already bring the screen, which then carries the delegation section too). It reads the live approvals
for the requested applications in one query (`TokenExchangeGrant.live_by_application`), needs the
screen when any application has none, and otherwise when any approval fails
`TokenExchangeGrant#remembered_and_current?` (CON-5 as amended, CON-12). The once-per-authorization
marker is `user_session[:delegation_consent_authorization]`, a SHA-256 of `sp_session[:request_url]`
set on submit; the SP request id was not used because it is reused across authorizations with the
same parameters while the authorize URL carries fresh `state` and `nonce`. No subtraction from
`verified_attributes` is needed: delegation values never enter `requested_attributes` (CON-6). The
screen is `_delegation_consent.html.erb`, rendered from `CompletionsPresenter#delegation_groups`
(agency-grouped rows with status `new`, `approved` or `updated` and the account-page approval time;
CON-7, CON-25, ACC-4); the locked checkboxes submit nothing, and `CompletionsController#update`
approves the applications recorded in the session through `TokenExchangeConsent` with the
`idv_form[delegation_remember]` choice (CON-9, CON-24), then logs `delegation_consent_submitted`.
Cancel is the existing `return_to_sp_cancel_path(step: :sign_up)` (CON-23). Strings are
`sign_up.delegation.*` in all four locales.

### 4.5 Requirements — storing consent

| ID | Requirement |
|---|---|
| **CON-10** | Approved delegations MUST be stored one row per (service provider identity, delegation scope) in a new `token_exchange_grants` table, recording the content versions the user saw and whether the user chose to be remembered. |
| **CON-11** | A grant is **valid** only if `revoked_at` is null, the service provider identity is not revoked (`identities.deleted_at` is null), and either `remember_until` is in the future or the grant belongs to the current authorization. `remember_until` MUST be at most one year after consent. |
| **CON-12** | If a scope's `content_version` or the service provider's `sp_content_version` is higher than the version recorded on the grant, the grant MUST be treated as not valid and consent re-collected. |
| **CON-13** | Revoking the service provider connection (`RevokeServiceProviderConsent`) MUST revoke all of that identity's grants. |
| **CON-19** | A grant MUST record the browser session (`rails_session_id`) in which consent was given. A non-remembered grant is "the current authorization" (CON-11) exactly while that value equals `identities.rails_session_id`, which the handoff sets from the same session; re-authorizing re-links the identity and the grant lapses. Recording a new decision for a scope MUST supersede (revoke with reason `superseded_by_new_consent`) any earlier live grant for the same identity and scope. |
| **CON-14** | Declined and not-remembered requests MUST also be recorded (status `declined`, or `remember_until: null`) so §9.4 can report on delegation that was requested but never used. A `declined` row is a reporting record only: it MUST NOT be read when deciding whether to show the consent screen or when pre-filling it (CON-9a). |

**`token_exchange_grants` — new table**

| Column | Type | Comment | Purpose |
|---|---|---|---|
| `id` | bigint | | |
| `identity_id` | FK → `identities` | sensitive=false | The service provider's `ServiceProviderIdentity` for this user |
| `token_exchange_scope_id` | FK → `token_exchange_scopes` | sensitive=false | |
| `delegation_id` | string, unique | sensitive=false | Random ID (`dlg_` + 22 urlsafe chars) shared with Attempts events and introspection (§6, §8) |
| `status` | string (enum: `consented`, `declined`, `revoked`) | sensitive=false | CON-14 |
| `scope_content_version`, `sp_content_version` | integer | sensitive=false | CON-12 |
| `consented_at` | datetime | sensitive=false | |
| `remember_until` | datetime, nullable | sensitive=false | `consented_at + 1.year` if remembered; null = this authorization only |
| `rails_session_id` | string | sensitive=true | The browser session in which consent was given. A non-remembered grant is valid only while this equals `identities.rails_session_id`, which the handoff sets from the same session; the next authorization re-links the identity and the grant lapses (CON-11 "belongs to the current authorization") |
| `proofed_in_session` | boolean | sensitive=false | User's profile was verified in this service provider session (§9.4) |
| `first_exchanged_at` | datetime, nullable | sensitive=false | §9.4 |
| `revoked_at`, `revocation_reason` | datetime, string | sensitive=false | |
| timestamps | | sensitive=false | |

Index: `(identity_id, token_exchange_scope_id) WHERE revoked_at IS NULL`.

**Why CON-19.** Nothing else ties a grant to one authorization: the identity row is reused across sign-ins,
the SP request id lives in Redis for hours, and the exchange runs outside the browser session. The
identity's `rails_session_id` is already rotated by `IdentityLinker` at every handoff, so comparing against it
gives "this authorization" for free at exchange time. Superseding keeps exactly one live decision per
scope, so a decline on a later screen ends an earlier approval instead of coexisting with it.

**Why one row per scope.** Consent must be revocable and auditable per API. A single flag per
service provider cannot express "approved API A, declined API B", and cannot show the user what they agreed to.

`app/models/token_exchange_grant.rb`:

```ruby
class TokenExchangeGrant < ApplicationRecord
  belongs_to :identity, class_name: 'ServiceProviderIdentity'
  belongs_to :token_exchange_scope

  MAX_REMEMBER = ServiceProviderIdentity::CONSENT_EXPIRATION  # 1.year

  scope :live, -> {
    where(status: 'consented', revoked_at: nil)
      .joins(:identity).merge(ServiceProviderIdentity.not_deleted)
  }

  def self.remembered_and_current_for(identity)
    live.where(identity:).where('remember_until > ?', Time.zone.now)
        .joins(:token_exchange_scope)
        .where('token_exchange_grants.scope_content_version = token_exchange_scopes.content_version')
  end

  def revoke!(reason:)
    update!(status: 'revoked', revoked_at: Time.zone.now, revocation_reason: reason)
    # cascades to tokens: see §7.5
  end
end
```

`app/services/revoke_service_provider_consent.rb#call` MUST add
`identity.token_exchange_grants.live.find_each { |g| g.revoke!(reason: 'connection_revoked') }`.

### 4.6 Requirements — telling the service provider what was approved

| ID | Requirement |
|---|---|
| **CON-15** | The token response from `/api/openid_connect/token` MUST include a `scope` value listing only the `token_exchange:*` values the user approved (RFC 6749 §5.1: `scope` is REQUIRED when it differs from the request). It MUST be computed **at token time** from the identity's live grants that are valid now, not stored on `identities.scope`, and MUST be present only when delegation was requested. |
| **CON-16** | The `id_token` MUST NOT list the target APIs in `aud`. `aud` stays the service provider's `client_id` (OpenID Connect Core §2). |

**Why CON-15's "at token time".** The handoff that follows the consent screen calls
`IdentityLinker#link_identity` again and overwrites `identities.scope` with the full requested list, so
anything filtered at consent time is lost. Limiting `scope` to delegation requests keeps existing token
responses byte-identical for current integrations.

**Why CON-16.** Every value in `aud` is a party the ID token is *for*. Listing targets there would
let a target API accept the service provider's ID token as if issued to itself — exactly the confused-
deputy problem this design exists to prevent.

`app/forms/openid_connect_token_form.rb#response` currently omits `scope`. Add
`scope: identity.scope` where `identity.scope` has been filtered to approved delegation values
at consent time.

*As built:* filtering `identity.scope` at consent time does not work, because the handoff that
follows the consent screen calls `IdentityLinker#link_identity` again and overwrites `scope` with the
full requested list. The token form therefore computes `scope` at token time: the identity's
attribute scopes plus the requested `token_exchange:*` values that have a live grant that is valid
now (remembered, or given in this authorization). `scope` is added to the response only when
delegation was requested, so existing integrations see an unchanged response.

### 4.7 Requirements — Account → Delegated access

| ID | Requirement |
|---|---|
| **ACC-1** | A new page under the account area MUST list every live, remembered grant grouped by service provider: service provider name and logo, operator, each approved API (agency, `display_name`, `access_type`), consent date, **time remaining** (`remember_until − now`), and whether a delegated or refresh token is currently active for it. |
| **ACC-2** | The page MUST offer *Revoke* per API and per service provider. Revoking calls `TokenExchangeGrant#revoke!`, which revokes every access and refresh token minted from the grant (§7.5) and emits `delegated-access-revoked` (§8). |
| **ACC-3** | The existing `/account/connected_services` page MUST link to the new page for any service provider with live grants. |

**Where.** Route `get '/account/delegated_access' => 'accounts/delegated_access#show'` and
`delete '/account/delegated_access/grants/:id' => 'accounts/delegated_access#revoke'` alongside
the existing `accounts/connected_services` routes (`config/routes.rb` ~247). Controller
`app/controllers/accounts/delegated_access_controller.rb`; view
`app/views/accounts/delegated_access/show.html.erb`; link from
`app/views/accounts/connected_services/show.html.erb`.

---

### 4.8 Amendments of 2026-10-09 (`login-delegated-access`)

Where a row below conflicts with §4.1–§4.7, this subsection governs.

| ID | Requirement |
|---|---|
| **CON-1** (amend) | A service provider requests delegation with one or more `token_exchange:<delegation_scope_value>` values, each naming an application (ONB-2 as amended). |
| **CON-2** (amend) | `invalid_scope` also when the application is inactive, its agency is inactive, or its `allowed_delegation_service_providers` is non-empty and excludes the requesting service provider. |
| **CON-5** (amend) | The screen is shown unless every requested application is covered by a live, remembered grant whose recorded content versions are at or above the current `*_material_version` of the agency, the application and the service provider. Editorial content edits never cause the screen to be shown. |
| **CON-7** (amend) | One row per requested application, grouped by agency: agency name and logo (`Agency#name`, CON-18), agency description, application display name, description, data provided, access type, learn-more link, and the application's resource server identifiers for information. Requested applications are rendered **checked and disabled**; the screen states that cancelling is how to decline. Nothing not requested is shown or approved by this screen. |
| **CON-9** (unchanged) | "Remember my approvals for 1 year", unchecked by default, applies to the requested applications. Unchecked means the grants are valid for this authorization only (CON-11, CON-19). |
| **CON-9a** (replace) | There is no per-application decline. Cancelling the screen creates no grant, completes no sign-in, and leaves no record at the service provider or any agency; it has no effect on whether the screen is shown next time. |
| **CON-10** (amend) | Grants are one live row per **(user, service provider issuer, application)** in `token_exchange_grants`: `user_id`, `service_provider_issuer`, `application_service_provider_id`, `delegation_id`, `source` (`consent_screen` or `account_page`), `consented_at`, `remember_until`, `rails_session_id` (single-authorization grants only), `agency_content_version`, `application_content_version`, `sp_content_version`, `proofed_in_session`, `first_exchanged_at`, `revoked_at`, `revocation_reason`. A new decision for the same key supersedes the earlier live row (revoked with reason `superseded_by_new_consent`). The grant is not tied to the service provider `identities` row because advance approval happens outside any authorization. |
| **CON-11** (amend) | A grant is valid when `revoked_at` is null, the application and its agency and the service provider are active, the service provider is still approved, and either `remember_until` is in the future or the grant is the current authorization (CON-19). An `account_page` grant always has `remember_until`. |
| **CON-12** (amend) | A grant is current only while `agency_content_version ≥ agencies.consent_material_version`, `application_content_version ≥ the application's consent_material_version` and `sp_content_version ≥ the service provider's sp_material_version`. Otherwise it is treated as not valid and consent is re-collected. |
| **CON-14** (amend) | Declined requests are no longer recorded (there are none). Not-remembered grants are still recorded (`remember_until: null`) for §9.4. The outcomes report counts consent screens shown without a completed authorization from analytics rather than from grant rows. |
| **CON-20** | `token_exchange:*` values that cannot be honored because the person cancelled MUST NOT produce any grant, Attempts delivery, billing row or agency-side record (ATT-*, BIL-*). |
| **ACC-1** (amend) | A dedicated page, `/account/delegated_access`, lists **every service provider approved for delegation**, connected or not, and under each **every active application that accepts that service provider** (ONB-2 as amended), grouped by agency in collapsible groups, each with: approval state and source, `consented_at`, time remaining, the application's resource servers and access type, and (from the token lifecycle feature) whether a delegated or refresh token is currently active. A service provider that is no longer approved or active keeps its section while live grants remain, offering only revocation. |
| **ACC-2** (amend) | Unapproved applications carry a checkbox; submitting the selection leads to a confirmation page that renders the selected applications with the consent-screen content, and one confirmation creates a grant per application with `source: account_page`, `remember_until = now + 12 months`. Approved rows offer Revoke; each section offers Revoke all. Every revocation has its own confirmation page and calls `TokenExchangeGrant#revoke!` with reason `user_revoked` (tokens cascade, §7.5; `delegated-access-revoked`, §8). |
| **CON-21** | Delegation scopes are accepted on OpenID Connect authorization requests only. A SAML AuthnRequest cannot request delegation; `requested_delegation_scopes` is set only by the OIDC authorize path. |
| **CON-22** | A request carrying `token_exchange:*` values whose ACR does not ask for identity verification (IAL2 or IALmax) fails with `invalid_scope`, not silently. |
| **CON-23** | Cancelling the consent screen uses the completions screen's existing cancel path: the person is returned to the service provider with `error=access_denied`, no sign-in completes, no grant, Attempts event or billing row is written. |
| **CON-24** | The remember choice applies only to requested applications without a live remembered approval. A requested application that already has one keeps that row untouched (no supersession, no shortening); it is re-recorded only when its approval is stale (CON-12) or absent. |
| **CON-25** | Each requested row is badged: `new` (no live approval), `already approved` (live, current approval) or `updated` (live approval made stale by a material content change). Only version numbers are stored; the updated row shows the current content. |
| **ACC-4** | Advance approvals from the account page are honored by the consent screen: a requested application with a live `account_page` grant counts as covered for CON-5 and, when the screen is shown for another application, is rendered checked, disabled and marked already approved. |
| **ACC-5** | Each approval and revocation made on the page writes an account history event (`delegation_approved`, `delegation_revoked`) and sends the person an email naming the service provider and the applications, with the standard disavowal link, from every confirmed email address, as `sp_user_consent_revoked` does today. |

**Why CON-7/CON-9a (amend).** The service provider's request is a condition of the sign-in, as requested attributes are today; a person who does not want a requested application declines the service provider, not the application. This removes the partial-approval states the earlier design had to report on and makes the screen's outcome binary.

**Why CON-10 (amend).** Advance approval happens with no service provider authorization in flight, so a grant keyed to the `identities` row or its session could not exist yet. Keying on the user, the service provider issuer and the application lets the account page and the consent screen read and write one row.

### 4.9 Amendments of 2026-10-09 (consent and account page follow-ups)

Where a row below conflicts with §4.3, §4.7 or §4.8, this subsection governs. Decided with the product owner on 2026-10-09 (implementation plan D52–D55).

| ID | Requirement |
|---|---|
| **CON-9** (confirmed) | The remember period is 12 months for every application, `read_write` included; no application has a shorter maximum. Read-write risk is carried by `max_access_token_seconds` and `max_family_seconds` (REF-5 as amended), not by the remember period. |
| **CON-26** | The service provider card (CON-7) carries one plain sentence stating how long the service provider's access lasts per sign-in (up to 12 hours, `token_exchange_refresh_token_ttl_seconds`), in every supported language. The screen says nothing about Attempts API delivery to agencies (§8); that disclosure is the privacy policy's. Added on `delegated-access-consent` as a follow-up to the consent feature. |
| **ACC-1** (amend) | The page lists **remembered** grants only (`remember_until` present and in the future); a single-authorization grant (`rails_session_id` set, `remember_until` null) is not shown. The page shows current state only: the "token active" indicator, first or last issuance times and any history list are not shown. Past approvals and revocations are visible through the account history events of ACC-5. |
| **ACC-2** (amend) | Revoke per application and Revoke all per service provider stand, each through its own confirmation page. The page additionally offers ACC-6. |
| **ACC-6** | A page-level **End all delegated access** action (`/account/delegated_access/revoke`, confirmation page listing every service provider and application that will lose access) revokes every live grant of the user across every service provider with reason `user_revoked` (tokens cascade, §7.5; one `delegated-access-revoked` event per grant, §8), writes one `delegation_revoked` account history event and sends one email naming every service provider and application (ACC-5). |
| **ACC-7** (planned) | A per-service-provider history on the page: approvals (source, remembered or not), revocations with `revocation_reason` (`user_revoked`, `sp_disconnected`, `superseded_by_new_consent`, material content change, `account_suspended`, `account_deleted`, `refresh_token_reuse`) and token issuance and refresh events, each with its date, for the last 12 months. Sourced from `token_exchange_grants` rows (never deleted; revoked and superseded rows stay) and the issuance record (§5.2 as amended); no new table. Depends on the account page and the token lifecycle feature. Planned 2026-10-09, not built this phase. |

**Why ACC-1 (amend).** A single-authorization grant lasts at most one sign-in and its family; listing it would show the person items that disappear on their own within hours and invite revocation of something that is ending anyway. Usage counts are the agency's to show, not Login.gov's: Login.gov knows when tokens were issued, not what the agency returned, and showing issuance times without that context was judged more confusing than useful.

---

**As built, 2026-10-09 (`delegated-access-account-page`).** Routes under `/account/delegated_access`: the page (`accounts/delegated_access#show`), `GET`/`POST …/:service_provider_id/approve` (selection then confirmation, `accounts/delegated_access/approvals`), and `GET`/`DELETE` confirmation routes for one application (`…/:service_provider_id/applications/:application_id/revoke`), one service provider (`…/:service_provider_id/revoke`) and everything (`…/revoke`) in `accounts/delegated_access/revocations`. `DelegatedAccessPresenter` builds the sections from `ServiceProvider.active.where(token_exchange_enabled_sp: true)` plus service providers named by the person's `TokenExchangeGrant.remembered` rows (ACC-1 as amended); rows pair each application with its remembered grant; single-sign-in grants are not shown (D54). `AccountDelegationApproval` writes `source: account_page` grants for the maximum period; `AccountDelegationRevocation` revokes at the three scopes with reason `user_revoked` (ACC-2, ACC-6). `DelegatedAccessNotificationConcern` records `delegation_approved`/`delegation_revoked` events and sends `UserMailer#delegation_approved`/`#delegation_revoked` (ACC-5). `RevokeServiceProviderConsent` revokes the service provider's grants with reason `sp_disconnected` (CON-13 as the companion names it, FR-CEN-14). The consent screen and the page render service provider and application content through the shared `DelegationServiceProviderCard` and partials. Token activity (ACC-1's last column) and the history view (ACC-7) are not part of this feature.

## 5. Token exchange (at the existing token endpoint)

### 5.1 Requirements

| ID | Requirement |
|---|---|
| **EXC-1** | Login.gov MUST implement RFC 8693 token exchange **at the existing token endpoint**, `POST /api/openid_connect/token`, selected by `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`, with `subject_token_type=urn:ietf:params:oauth:token-type:access_token` and the RFC 8707 `resource` parameter naming exactly one registered resource server. No new route is added for the exchange. |
| **EXC-2** | For the token-exchange and refresh grant types, the service provider MUST authenticate with `private_key_jwt` (RFC 7523) using the certificates on its SP record, validated by the same code path the authorization-code grant uses today (`OpenidConnectTokenForm#validate_client_assertion`, with `aud` = the token endpoint URL). `code_verifier` (PKCE) MUST NOT be accepted for these grant types, even for SPs configured with `pkce: true`. Requests without a valid client assertion MUST fail with `invalid_client`. The token endpoint's existing CORS rule is unchanged; a browser cannot produce a client assertion, so these grant types are unusable from a browser regardless of CORS. |
| **EXC-3** | Login.gov MUST mint only when **all** of the following hold: the subject token belongs to the authenticated service provider; the service provider is a service provider approved for delegation; the service provider's identity has IAL2 (or IALmax with a verified user) and the user's profile is active; a valid grant (CON-11, CON-12) exists for a delegation scope belonging to the requested `resource`; the resource server, its scope, its owning SP and the service provider are all active. Otherwise it MUST return an RFC 8693 §2.2.2 error (`invalid_target` for resource problems, `invalid_grant` for token/consent problems, `invalid_client` for authentication). |
| **EXC-4** | The minted token MUST be an opaque random string, stored **hashed** in a new `token_exchange_tokens` table, with `aud` = the resource server identifier, `scope` = the approved delegation scope values for that resource, the service provider as actor, the grant, the `delegation_id`, the forwarded IAL/AAL, and its own `expires_at` (default 15 minutes). |
| **EXC-5** | The exchange MUST NOT create, update or read the agency SP's `identities` row, MUST NOT return an `id_token`, and MUST NOT create an authorization code. |
| **EXC-6** | A token minted by exchange MUST be rejected as `subject_token` (no chained delegation), and MUST be rejected by `/api/openid_connect/userinfo`. |
| **EXC-7** | The response MUST include `access_token`, `issued_token_type`, `token_type`, `expires_in`, `scope`, and, per §7, `refresh_token`. |
| **EXC-8** | The exchange MUST be rate-limited per service provider (RateLimiter keyed on the service provider issuer), not only per IP. |
| **EXC-9** | Login.gov MUST accept an RFC 9449 `DPoP` header on the token-exchange grant. When present and valid (RFC 9449 §4.3: `typ`, allowed `alg`, public-only `jwk`, signature, `htm`, `htu`, `iat` within the acceptance window, unused `jti`), the minted token and its refresh family MUST be bound to the proof key by storing its RFC 7638 thumbprint (`dpop_jkt`), and `token_type` MUST be `DPoP` (`N_A` for a SAML assertion, which carries the thumbprint as a `dpop_jkt` attribute instead). A proof that is present but invalid MUST fail with `invalid_dpop_proof`. If the resource server has `dpop_required: true` and no proof is present, the exchange MUST fail with `invalid_dpop_proof` (RFC 9449 §5). Without a proof, and when the resource server does not require one, the token is an ordinary bearer token (RFC 6750). The proof is checked after every other validation so an unauthenticated or unauthorized caller learns nothing about the API's policy. |
| **EXC-10** | The implementation MUST follow the token endpoint's existing conventions: `OpenidConnect::TokenController#create` dispatches on `grant_type` to a form object; the form exposes `#submit` (returning a `FormResponse`) and `#response`; the controller logs `analytics.openid_connect_token` with the form's attributes and `analytics.sp_integration_errors_present` when `integration_errors` are present; parameters are read through `params.permit`; the response is rendered with `render json:` and status `:ok` on success or `:bad_request` on failure. |
| **EXC-12** | The subject token's sign-in session MUST still be live at exchange time (the same `OutOfBandSessionAccessor` TTL check `userinfo` applies); otherwise `invalid_grant`. Once minted, the delegated family no longer depends on that session (REF-6). |
| **EXC-13** | An optional `scope` parameter MAY narrow the minted token to a subset of the values the user approved for that resource; any value outside the approved set fails with `invalid_scope` rather than being dropped. Absent `scope`, every approved value for the resource is included. |
| **EXC-14** | All live grants for the requested resource are exchanged together into one token; the earliest grant's `delegation_id` identifies the exchange to the agency (introspection, Attempts events, billing `request_id`). |
| **EXC-15** | A caller that authenticates but is not approved for delegation fails with `invalid_client`, not `invalid_grant`: approval is a property of the client. A caller over its rate limit fails with HTTP 400 `invalid_request` at the token endpoint (RFC 6749 §5.2 defines no 429 there); introspection, which has no RFC-defined error set for this case, answers HTTP 429 (RFC 6585) with `invalid_request`. |
| **EXC-16** | The exchange response MUST include `refresh_token_expires_in` (seconds until the family ends) alongside `expires_in`, and both MUST be computed from the single instant at which the token row was created, so a service provider can schedule refreshes without clock arithmetic against the response time. |
| **EXC-11** | Error responses MUST keep the token endpoint's current shape — a JSON object with an `error` key and HTTP 400 — and MUST set `error` to the RFC 6749 §5.2 / RFC 8693 §2.2.2 code (`invalid_client`, `invalid_grant`, `invalid_target`, `invalid_scope`, `unsupported_grant_type`, `invalid_request`) with the human-readable message in `error_description`. This is additive to today's behavior, which puts message text in `error`; existing authorization-code clients are unaffected. |

**Why EXC-12.** A Login.gov access token is otherwise valid forever in the database; requiring a live
sign-in session means an old or stolen SP token cannot start a *new* delegation days later, while the
family it opens legitimately outlives the session by design.

**Why EXC-13/EXC-14.** The consent model is one grant per scope, but a resource server receives one
token. Combining the resource's approved scopes into one token keeps "one token per API" (EXC-4) and lets
a service provider request less than it was granted (least privilege); a single `delegation_id` per
exchange keeps the agency's join key stable.

**Why EXC-5.** The natural shortcut is to reuse `IdentityLinker#link_identity` against the target
SP. That has side effects introspection cannot undo: it sets `last_consented_at` (recording
consent to the target the user never gave on the target's screen), clears `deleted_at` (reviving
a connection the user revoked), stamps `last_ial2_authenticated_at`, and rotates the target's
`access_token` and `rails_session_id` — killing any direct session the user has at the target.
It also means a user cannot be signed in directly and delegated at the same time. A separate
table has none of these problems and allows one token per API.

**Why EXC-6, second half.** `userinfo` authenticates by looking the token up in
`identities.access_token` (`AccessTokenVerifier`). Because delegated tokens live in a different
table they are never found there, which satisfies the requirement automatically. Do not add a
lookup path.

### 5.2 Tables

**`token_exchange_tokens` — new table**

| Column | Type | Comment | Purpose |
|---|---|---|---|
| `id` | bigint | | |
| `token_digest` | string, unique | sensitive=false | SHA-256 of the access token |
| `grant_id` | FK → `token_exchange_grants` | sensitive=false | |
| `resource_server_id` | FK → `token_exchange_resource_servers` | sensitive=false | `aud` |
| `service_provider_id` | FK → `service_providers` | sensitive=false | `act.sub` |
| `user_id` | FK → `users` | sensitive=false | |
| `scope` | string | sensitive=false | Space-separated approved values for this resource |
| `ial`, `aal` | integer | sensitive=false | Forwarded from the service provider's identity |
| `refresh_family_id` | string | sensitive=false | Links to `token_exchange_refresh_tokens` (§7) |
| `dpop_jkt` | string, nullable | sensitive=false | RFC 7638 thumbprint of the key the token is bound to (EXC-9); null for a bearer token |
| `sp_rails_session_id` | string, nullable | sensitive=false | For audit and §8 live events only; **not** used for validity |
| `expires_at` | datetime | sensitive=false | |
| `revoked_at`, `revocation_reason` | datetime, string | sensitive=false | |
| timestamps | | sensitive=false | |

**Amended 2026-10-09 (D26).** Storage is hybrid, and the live access token is **not** looked up in this table. At mint, Login.gov writes a Redis entry keyed by the token's SHA-256 digest (`delegated_token:<digest>`), with a TTL equal to the token's lifetime, holding `aud`, `scope`, `grant_id`, `delegation_id`, `user_id`, `service_provider_id`, `resource_server_id`, `ial`, `aal`, `refresh_family_id`, `dpop_jkt`, `sp_rails_session_id`, `token_format`, `expires_at` and the id of the issuance row; it adds the digest to two index sets, `delegated_tokens:grant:<grant_id>` and `delegated_tokens:family:<refresh_family_id>`, each with a TTL no shorter than the family's. Introspection (§6) and the chained-delegation check (EXC-6) read the Redis entry; an absent entry means not active. This table becomes the **issuance record**: one row per issued access token or SAML assertion, with `grant_id`, `resource_server_id`, `service_provider_id`, `user_id`, `delegation_id`, `refresh_family_id`, `token_format`, `token_type` (`Bearer`, `DPoP` or `N_A`), `dpop_jkt`, `expires_at`, `revoked_at`, `revocation_reason` and timestamps. It holds no digest and no other secret, and nothing reads it to decide validity; it serves billing (§9), the Attempts events (§8), the account page (ACC-1, "token active") and audit. The `token_digest` column above is superseded; `jti` (INT-4) is still derived from the digest, which introspection computes from the presented token. Revocation (§7.5 as amended) deletes the Redis entries listed in the grant's or family's index set and marks the issuance rows revoked; expiry needs no job. SAML-7 is read the same way: the digest of the assertion `ID` is the Redis key and the issuance row records the assertion. Refresh tokens (§7.2) stay in Postgres unchanged. Rejected: Postgres-only (table growth and purge jobs for tokens that expire on their own) and Redis-only (no durable refresh family or issuance history).

### 5.3 Where and how

**Routes** (`config/routes.rb`). The exchange reuses the existing
`post '/api/openid_connect/token' => 'openid_connect/token#create'` route. Two new routes, next
to it, for the endpoints whose RFCs define them separately:

```ruby
post '/api/openid_connect/introspect' => 'openid_connect/introspect#create'   # §6, RFC 7662
post '/api/openid_connect/revoke'     => 'openid_connect/revoke#create'       # §7, RFC 7009
```

Neither new route gets an `OPTIONS` route or a `Rack::Cors` entry in `config/application.rb`:
both are called only by servers. The existing `/api/openid_connect/token` CORS rule stays as it
is for PKCE clients.

**Amended 2026-10-09 (D59).** Both new routes get the same `Rack::Cors` entry as `/api/openid_connect/token` (origins limited to registered redirect URIs through `IdentityCors.allowed_redirect_uri?`, any request header, `POST` and `OPTIONS`), because the public-client service provider revokes its families (REF-8) and introspects its own tokens (INT-14 as amended) from the browser. Agencies calling with `private_key_jwt` never preflight and are unaffected.

**Controller** — extend `app/controllers/openid_connect/token_controller.rb#create` to dispatch on
`grant_type`, keeping everything after form construction exactly as it is today:

```ruby
module OpenidConnect
  class TokenController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    TOKEN_EXCHANGE_GRANT = 'urn:ietf:params:oauth:grant-type:token-exchange'

    def create
      @token_form = build_form
      result = @token_form.submit
      response = @token_form.response

      analytics_attributes = result.to_h
      analytics_attributes[:expires_in] = response[:expires_in]
      analytics.openid_connect_token(**analytics_attributes.except(:integration_errors))
      if !result.success? && analytics_attributes[:integration_errors].present?
        analytics.sp_integration_errors_present(**analytics_attributes[:integration_errors])
      end

      render json: response, status: (result.success? ? :ok : :bad_request)
    end

    private

    def build_form
      case params[:grant_type]
      when TOKEN_EXCHANGE_GRANT
        return OpenidConnectUnsupportedGrantForm.new unless IdentityConfig.store.token_exchange_enabled
        OpenidConnectTokenExchangeForm.new(token_params)
      when 'refresh_token'
        return OpenidConnectUnsupportedGrantForm.new unless IdentityConfig.store.token_exchange_enabled
        OpenidConnectRefreshTokenForm.new(token_params)
      else
        OpenidConnectTokenForm.new(token_params)
      end
    end

    def token_params
      params.permit(:client_assertion, :client_assertion_type, :code, :code_verifier, :grant_type,
                    :subject_token, :subject_token_type, :resource, :refresh_token, :scope)
    end
  end
end
```

`OpenidConnectUnsupportedGrantForm` is a tiny form whose `#response` is
`{ error: 'unsupported_grant_type' }`, so the feature flag produces the RFC 6749 error rather
than a 404. The existing `OpenidConnectTokenForm` keeps validating `grant_type` against
`%w[authorization_code]` and is otherwise untouched.

**Form** `app/forms/openid_connect_token_exchange_form.rb`. Validation order matters: authenticate
the client first so nothing about a token is revealed to an unauthenticated caller.

```ruby
class OpenidConnectTokenExchangeForm
  include ActiveModel::Model

  GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
  ACCESS_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token'

  validate :validate_client_assertion          # RFC 7523; reuse the logic from OpenidConnectTokenForm
  validate :validate_grant_and_token_types
  validate :validate_subject_token             # belongs to *this* service provider, session live, IAL2
  validate :validate_service provider_approved
  validate :validate_resource                  # active resource server
  validate :validate_grant                     # CON-11, CON-12 for a scope on that resource
  validate :validate_rate_limit                # EXC-8

  def submit
    @success = valid?
    mint! if @success
    FormResponse.new(success: @success, errors:, extra: analytics_extra)
  end

  # Same shape as OpenidConnectTokenForm#response: a hash the controller renders as JSON.
  def response
    return { error: error_code, error_description: errors.full_messages.join(' ') } unless @success   # EXC-11
    {
      access_token: @access_token,
      issued_token_type: ACCESS_TOKEN_TYPE,
      token_type: 'Bearer',                     # 'DPoP' only if Appendix C is adopted
      expires_in: IdentityConfig.store.token_exchange_access_token_ttl_seconds,
      scope: @minted.scope,
      refresh_token: @refresh_token,                                              # §7
      refresh_token_expires_in: IdentityConfig.store.token_exchange_refresh_token_ttl_seconds,
    }
  end

  private

  def mint!
    @access_token = SecureRandom.urlsafe_base64(32)
    @minted = TokenExchangeToken.create!(
      token_digest: Digest::SHA256.hexdigest(@access_token),
      grant: grant, resource_server: resource_server,
      service_provider: requesting_sp, user: sp_identity.user,
      scope: grant_scope_values.join(' '),
      ial: sp_identity.ial, aal: sp_identity.aal,
      sp_rails_session_id: sp_identity.rails_session_id,
      expires_at: IdentityConfig.store.token_exchange_access_token_ttl_seconds.seconds.from_now,
      refresh_family_id: SecureRandom.uuid,
    )
    @refresh_token = TokenExchangeRefreshToken.issue_for(@minted)               # §7
    grant.update!(first_exchanged_at: grant.first_exchanged_at || Time.zone.now) # §9.4
    DelegatedBillingEvent.record(@minted)                                        # §9
    AttemptsApi::DelegatedEvents.token_issued(@minted)                           # §8
  end
end
```

**Errors** (EXC-11; codes from RFC 8693 §2.2.2 and RFC 6749 §5.2, all HTTP 400 per the token
endpoint's existing convention): `invalid_client` for a missing or bad client assertion;
`invalid_grant` for a bad, expired or foreign subject token or a missing/expired grant;
`invalid_target` for an unknown or inactive resource or one the grant doesn't cover;
`unsupported_grant_type`; `invalid_request`.

**Rate limiting.** Add a `token_exchange_per_sp` entry to `RateLimiter.load_rate_limit_config`
(`app/services/rate_limiter.rb`) with `max_attempts` / `attempt_window` from two new
`IdentityConfig` keys, and call `RateLimiter.new(target: requesting_sp.issuer, rate_limit_type:
:token_exchange_per_sp)`.

**Analytics.** Add `openid_connect_token_exchange(success:, sp_issuer:, resource:, error_details: nil, **extra)`
to `app/services/analytics_events.rb` with the documented `@param` style used there.

### 5.4 Discovery document

| ID | Requirement |
|---|---|
| **DISC-1** | `/.well-known/openid-configuration` (`OpenidConnectConfigurationPresenter`) MUST advertise every new grant type and endpoint using the metadata names defined by OpenID Connect Discovery 1.0 and RFC 8414 §2: `grant_types_supported` adds `refresh_token` and `urn:ietf:params:oauth:grant-type:token-exchange`; `introspection_endpoint`, `introspection_endpoint_auth_methods_supported` and `introspection_endpoint_auth_signing_alg_values_supported`; `revocation_endpoint`, `revocation_endpoint_auth_methods_supported` and `revocation_endpoint_auth_signing_alg_values_supported`. |
| **DISC-2** | Discovery MUST include `dpop_signing_alg_values_supported` (`["ES256", "RS256"]`, RFC 9449 §5.1) while delegated access is enabled. |
| **DISC-3** | No non-standard metadata key MUST be added. In particular there is no `token_exchange_endpoint`: RFC 8693 performs exchange at `token_endpoint`, which is already advertised. |
| **DISC-4** | `scopes_supported` remains the static `VALID_SCOPES` list. `token_exchange:*` values are per-partner and MUST NOT be enumerated in discovery; the developer documentation describes the prefix. |
| **DISC-5** | Metadata for the new endpoints MUST appear only when `token_exchange_enabled` is true, so the document never advertises something that returns `unsupported_grant_type` or 404. |

```ruby
# app/presenters/openid_connect_configuration_presenter.rb
def configuration
  {
    acr_values_supported: Saml::Idp::Constants::VALID_AUTHN_CONTEXTS,
    claims_supported: claims_supported,
    grant_types_supported: grant_types_supported,
    response_types_supported: %w[code],
    scopes_supported: OpenidConnectAttributeScoper::VALID_SCOPES,          # DISC-4
    subject_types_supported: %w[pairwise],
  }.merge(url_configuration).merge(crypto_configuration).merge(delegation_configuration)
end

private

def grant_types_supported
  base = %w[authorization_code]
  return base unless IdentityConfig.store.token_exchange_enabled            # DISC-5
  base + %w[refresh_token urn:ietf:params:oauth:grant-type:token-exchange]
end

def delegation_configuration
  return {} unless IdentityConfig.store.token_exchange_enabled              # DISC-5
  {
    introspection_endpoint: api_openid_connect_introspect_url,              # RFC 8414 §2
    introspection_endpoint_auth_methods_supported: %w[private_key_jwt],
    introspection_endpoint_auth_signing_alg_values_supported: %w[RS256],
    revocation_endpoint: api_openid_connect_revoke_url,
    revocation_endpoint_auth_methods_supported: %w[private_key_jwt],
    revocation_endpoint_auth_signing_alg_values_supported: %w[RS256],
  }
end
```

The Attempts API's `/.well-known/ssf-configuration` needs no change: the SSF transmitter
metadata Login.gov publishes today has no per-event-type list.

**Amended 2026-10-09 (D46, D48).** DISC-2 and DISC-5 are confirmed: `grant_types_supported` additions, `introspection_endpoint` and its two auth members, `revocation_endpoint` and its two auth members, `token_endpoint_auth_methods_supported` (`private_key_jwt` and `none`, the latter for the public-client service provider) and `dpop_signing_alg_values_supported: ["ES256", "RS256"]` appear only while `token_exchange_enabled` is true. `token_endpoint_auth_methods_supported` is the one member not listed in DISC-1; it is advertised behind the same switch because `none` is only meaningful once public clients can exchange.

---

### 5.5 Amendments of 2026-10-09 (public-client service provider)

Where a row below conflicts with §5.1–§5.4 or §7, this subsection governs. Confirmed by the product owner on 2026-10-09.

| ID | Requirement |
|---|---|
| **EXC-2** (amend) | Client handling at the token endpoint depends on the client type fixed at onboarding. A **confidential** service provider authenticates with `private_key_jwt` as before. A **public** service provider (`pkce: true`) sends `client_id` without a client assertion; for the token-exchange and refresh grants it MUST present a DPoP proof (RFC 9449 §4.3) whose key thumbprint equals the `cnf.jkt` of the subject or refresh token it presents, with `ath` over that token (§4.3 item 12, §7.1). `code_verifier` is still refused on these grants. |
| **EXC-17** | For a public service provider approved for delegation, DPoP is mandatory: the authorization-code grant, the token-exchange grant, the refresh grant and `/api/openid_connect/userinfo` each require a valid proof, and a token issued to such a client carries `token_type: DPoP` and `cnf.jkt`. A request from such a client without a proof fails with `invalid_dpop_proof` (§5) or, at userinfo, `401` with `WWW-Authenticate: DPoP` (§7.1). Confidential clients and their bearer tokens are unaffected. |
| **EXC-18** | `/api/openid_connect/userinfo` MUST verify the DPoP proof for a bound service-provider access token (`htm`, `htu`, `iat`, `jti`, `ath`, thumbprint equal to the token's `cnf.jkt`) and MUST refuse a bound token presented as a bearer token (RFC 9449 §7.1). Delegated tokens remain refused at userinfo regardless of proof (EXC-6). |
| **EXC-19** | A public service provider approved for delegation MUST send `dpop_jkt` on the authorization request (RFC 9449 §10); Login.gov MUST bind the issued authorization code to that thumbprint and refuse a code exchange whose proof key differs. |
| **REF-2** (amend) | Refresh tokens issued to a public service provider are bound to the DPoP key (RFC 9449 §5); the refresh grant MUST carry a proof from that key and no client assertion. Refresh tokens of confidential clients are protected by `private_key_jwt` as before. |

**Why.** A browser-based service provider has no secret to keep, so client authentication cannot protect its tokens; sender constraint can. Binding every token the service provider holds, and verifying the proof wherever Login.gov accepts one of them, means a token exfiltrated from the browser is useless to the thief. Keeping delegated tokens out of userinfo keeps each agency's attributes reachable only by that agency.

### 5.6 Amendments of 2026-10-09 (token exchange interview)

Where a row below conflicts with §5.1–§5.5, this subsection governs. Decided with the product owner on 2026-10-09 (implementation plan D26–D31, D37).

| ID | Requirement |
|---|---|
| **EXC-1** (confirmed) | Exactly one `resource` per exchange; a request naming two or more fails with `invalid_request`. RFC 8707 permits several values; Login.gov issues one token with one audience. |
| **EXC-3** (amend) | When the authenticated caller names a registered, active resource whose application accepts it, and the person has no live, current grant (CON-11, CON-12) for that application, the error is `consent_required` with `error_description` naming the application's `token_exchange:<value>` scope, so the service provider can start an authorization request for it. The error is given only after the caller is authenticated and the resource found; a resource that is unknown, inactive, or whose application excludes the caller fails with `invalid_target` as before (E26 narrowed). |
| **EXC-4** (amend) | The minted token is an opaque random reference. The live token is a Redis entry keyed by its SHA-256 digest with a TTL equal to its lifetime, and the `token_exchange_tokens` row is the secret-free issuance record (§5.2 as amended). Lifetime is `token_exchange_access_token_ttl_seconds` (default 900) or the resource server's `max_access_token_seconds` when that is lower; never higher. |
| **EXC-8** (replace) | The exchange is not rate-limited per service provider and never refuses a request for volume. Login.gov logs every exchange and failure through analytics and monitors volume and error rate per service provider against configurable alert thresholds (§10 as amended). Runaway-caller protection is the infrastructure layer's (edge and load balancer), not the application's. |
| **EXC-12** (confirmed) | The subject token's sign-in session must be live at the first exchange (E2 confirmed); the family it opens then runs independently of that session (REF-6). |
| **EXC-15** (amend) | The rate-limit sentences are withdrawn with EXC-8 and INT-7; `invalid_client` for an authenticated caller not approved for delegation stands. |
| **EXC-20** | Delegated tokens MUST NOT be JWTs or any other self-describing format; a resource server learns a token's meaning only by introspection (§6), and the service provider learns nothing from the string. |
| **EXC-9** (amend 2026-10-09, D47) | The `dpop_required` clause is withdrawn: there is no per-resource-server requirement. A public service provider's exchange always carries a proof (EXC-17) and a confidential service provider's never does; the proof's `alg` MUST be `ES256` or `RS256` (DISC-2). |
| **EXC-21** (D44) | `requested_token_type` is REQUIRED on every exchange; a request without it fails with `invalid_request`. The service provider chooses `urn:ietf:params:oauth:token-type:access_token` or `urn:ietf:params:oauth:token-type:saml2` (SAML-1 and SAML-3 as amended in §15.8). |

**Why EXC-3 (amend).** Without a distinct error the service provider cannot tell "the person never approved this application" from "this resource does not exist"; with it, the service provider sends the person through a sign-in that requests the scope, which is the only way to obtain the approval. The detail is withheld from unauthenticated callers and for unregistered resources so the endpoint is not an oracle for the registry or for a person's approvals.

**Why EXC-8 (replace).** A service provider in nationwide use acts for many people at several agencies in quick succession, and an agency gateway introspects for every one of them; any per-caller ceiling low enough to matter would refuse legitimate traffic first. Alerting on volume and error rate gives operations the same signal without the refusal.

**As built, 2026-10-10 (`delegated-access-token-exchange`).** Routes: `POST /api/openid_connect/token` serves the exchange; `OpenidConnect::TokenController#build_form` dispatches on `grant_type` to `OpenidConnectTokenForm` (`authorization_code`), `OpenidConnectTokenExchangeForm` (the RFC 8693 URN while `token_exchange_enabled` is on) or `OpenidConnectUnsupportedGrantForm` (`unsupported_grant_type` for anything else); `/api/openid_connect/exchange` and its CORS rule are removed. The proof is read from the `DPoP` header only. Redis as built: `delegated_token:<hex SHA-256 of the token>` holds `aud`, `scope`, `grant_id`, `delegation_id`, `user_id`, `service_provider_id`, `resource_server_id`, `ial`, `aal`, `refresh_family_id`, `dpop_jkt`, `token_type`, `token_format`, `sp_rails_session_id`, `issued_at`, `expires_at` and `issuance_id` with TTL equal to the lifetime; `delegated_tokens:grant:<grant_id>` and `delegated_tokens:family:<refresh_family_id>` list the digests and their TTL only grows (`DelegatedTokenStore`). The issuance record `token_exchange_tokens` (migration `20261009100700`) has `grant_id`, `resource_server_id`, `service_provider_id`, `user_id`, `delegation_id`, `scope`, `ial`, `aal`, `refresh_family_id`, `token_type` (`Bearer`, `DPoP`, `N_A`), `token_format`, `dpop_jkt`, `sp_rails_session_id` (sensitive), `issued_at`, `expires_at`, `revoked_at`, `revocation_reason`; no digest column. The record is written in one transaction with the grant's `first_exchanged_at`, and the Redis entry only after commit. Lifetime is the lower of `token_exchange_access_token_ttl_seconds` (900) and `token_exchange_resource_servers.max_access_token_seconds` (migration `20261009100600`). Validation order, stopping at the first failure: client (`invalid_client`: a confidential client's assertion through `ResourceServerAuthenticator`, a public client's `client_id` naming a `pkce` record, approval for delegation), request shape (`invalid_request`: `subject_token_type`, `subject_token`, `requested_token_type` present and known, exactly one `resource`, no `code_verifier`), subject token (`invalid_grant`: the caller's own live `identities` row, bound for a public client), the public client's proof (`invalid_dpop_proof`: `ath` over the subject token, thumbprint equal to `identities.dpop_jkt`), session live and identity-verified, not suspended (`invalid_grant`), resource usable and accepting the caller (`invalid_target`, one wording), `saml2` not yet available (`invalid_target`), approval live and current (`consent_required` naming the scope). The optional narrowing `scope` of E3 and EXC-13 is not read; the issued scope is the application's. Response: `access_token`, `issued_token_type`, `token_type`, `expires_in`, `scope`; no `refresh_token` until §7 is built, no `id_token`. DPoP binding starts at the authorization request: a public client approved for delegation must send `dpop_jkt` (stored on `identities.dpop_jkt`, migration `20261009100500`), the code exchange requires a proof from that key (`OpenidConnectTokenForm#validate_dpop_proof`, no `ath`) and answers `token_type: DPoP`, and the exchange binds the delegated token to the same key. `DpopProofVerifier` accepts `iat` within `dpop_proof_max_age_seconds` (300) either side of now and keeps each `jti` per key for twice that window; no `DPoP-Nonce` (Appendix C and E57 as amended, E98). Re-approval moves live tokens to the replacement row (`TokenExchangeGrant#transfer_live_tokens_to!`, `DelegatedTokenStore.move_grant`; E97); `TokenExchangeGrant#revoke!` removes the live entries and marks the issuance rows (§7.5). The sample service provider in `config/delegated_access.localdev.yml` is a public client (`pkce: true`, no `certs`) and the records API carries `max_access_token_seconds: 300`.

---

## 6. Introspection and enforcement

### 6.1 Requirements

| ID | Requirement |
|---|---|
| **INT-1** | Login.gov MUST expose `POST /api/openid_connect/introspect` per RFC 7662. Callers MUST authenticate with `private_key_jwt` using the certificates on their `token_exchange_resource_servers` row. Unauthenticated or unknown callers MUST receive HTTP 401. |
| **INT-2** | For an authenticated caller, Login.gov MUST return `{"active": true, ...}` only when: the token exists and `expires_at` is in the future and `revoked_at` is null; the token's resource server **is the caller**; the grant is valid (CON-11, CON-12); the resource server, scope, owning SP and service provider are active; and the user's account is not suspended or deleted. |
| **INT-3** | In every other case Login.gov MUST return exactly `{"active": false}` with HTTP 200 (RFC 7662 §2.2), and MUST NOT indicate why. |
| **INT-4** | The active response MUST include `iss`, `aud`, `scope`, `sub`, `act`, `acr`, `exp`, `iat`, `jti`, `auth_time`, `client_id` (the service provider) and `delegation_id`. `jti` identifies this one token (derived from the stored digest, never the digest itself, so it says nothing about issuance volume); `delegation_id` identifies the consent and is shared by every token in the refresh family. `auth_time` is when the user last authenticated to the service provider, the sign-in the delegation rests on, the same instant the SAML `AuthnInstant` carries. Together these give the resource server every element NIST IR 8587 §5.2.1.1 requires of a token it relies on. `act` MUST always be present on delegated tokens. For a key-bound token it MUST also include `cnf: { jkt: <thumbprint> }` (RFC 9449 §6, RFC 7800), the key the resource server must verify a proof against on the request it received. |
| **INT-10** | **Decided 2026-09-29.** The active response MUST also carry the identity claims the agency would receive from `userinfo` for a direct sign-in — the same claim names and formats `OpenidConnectUserInfoPresenter` produces (`email`, `email_verified`, `all_emails`, `given_name`, `family_name`, `birthdate`, `social_security_number`, `address`, `phone`, `phone_verified`, `verified_at`, `ial`, `aal`, `x509_*`) — limited to the **agency SP's configured `attribute_bundle`** and keyed by the agency's pairwise `sub`. Identity attributes come from the user's decrypted PII, which exists only while the service provider's Login.gov session is live (the same rule as SAML-5b); after it ends the response carries identifiers and email only plus `attributes: "identifiers_only"`. Delegated tokens remain unusable at `userinfo` (EXC-6). |
| **INT-5** | `sub` MUST be the user's pairwise identifier for the **resource server's owning agency**, computed the same way `userinfo` computes it (`AgencyIdentityLinker`). |
| **INT-6** | The client assertion MUST be validated per RFC 7523 §3 and RFC 8725: RS256 (pinned), `iss` = `sub` = the resource server identifier, `aud` = the introspection URL, `exp` **required** and at most 5 minutes after `iat`, and `jti` not previously seen within that window. |
| **INT-7** | Introspection MUST be rate-limited per resource server. |
| **INT-9** | The active response MUST include `token_type` (`Bearer`, or `DPoP` for a key-bound token) so a resource server can refuse a bound token presented with the wrong scheme. Introspection calls over the per-resource-server limit MUST answer HTTP 429 with `error: invalid_request`; all other failures to authenticate MUST answer HTTP 401 `invalid_client`. |
| **INT-11** | Claim release under INT-10 is decided by the **agency SP's bundle alone**, never by the service provider's sign-in scopes: the user consented to the agency's bundle and to the service provider acting, not to the service provider choosing what the agency learns. `first_name` and `last_name` are filtered individually (OIDC's `profile:name` would release both); any address component in the bundle releases the whole composite `address` claim, as the SAML presenter already does. Claims absent from the bundle are omitted, never `null`; `locale` is never included. `auth_time` is not an identity claim and is carried as a token member (INT-4), not as part of the bundle. |
| **INT-12** | `attributes: "identifiers_only"` is present only when the bundle contains proofed attributes *and* PII cannot be loaded; a bundle such as `[email]` never carries it. `ial` is the verified ACR only when the token's stored IAL is 2 (or IALmax) and the user holds an active profile — otherwise the auth-only ACR with no proofed claims — so a resource server MUST NOT assume proofed claims are present merely because `active` is true. `aal` falls back to the identity's requested AAL, then the default classref, exactly as `userinfo` reports. |
| **INT-13** | `email` is the address the user chose to share with the **service provider** (the identity's shared email); a delegated-only user has no identity row at the agency to hold a separate choice. `verified_at` is an integer epoch (userinfo format), while the SAML assertion carries ISO 8601 — each protocol keeps its own convention (Appendix E, E24). |
| **INT-8** | Login.gov MUST publish a maximum cache window (initially 60 seconds) that resource servers may rely on before re-introspecting. |

**Why INT-10 (and why not `userinfo`).** The design principle is that an agency application behaves
exactly as it does for a direct sign-in, with introspection as the only added step; agencies already
consume identity as userinfo claims, so the same claims must arrive for a delegated token, and the OAuth
path must match what SAML consumers get in the assertion (SAML-5). They cannot come from `userinfo`:
that endpoint authenticates no one, so the *service provider* holding the delegated token could read the
agency's bundle — attributes the user never approved for it (its own sign-in scopes may be narrower).
Introspection is authenticated to the resource server, so only the audience learns the attributes; RFC 7662
§2.2 permits extension members. Requiring the resource server's client assertion at `userinfo` instead
would make Login.gov's `userinfo` unlike any other provider's for no gain.

**Why INT-5 and INT-4 together.** Login.gov's `sub` is per *agency*, not per SP
(`AgencyIdentityLinker.for` keys on `agency_id`). If the service provider and the target belong to the
same agency, `sub` is identical for direct and delegated access. `act` is therefore the only
way an API can tell that a service provider, not the user, is calling. That is why it is mandatory.

**Why INT-6 is stricter than `/token` today.** `OpenidConnectTokenForm#validate_client_assertion`
does not check `jti`, treats `exp` as optional (ruby-jwt only verifies `exp` when present), and
checks `iat` only for not being in the future. Those gaps are tolerable for a one-shot code
exchange; introspection is called thousands of times a day by machines, so replay protection
and a lifetime bound are required. Consider back-porting them to `/token`.

### 6.2 Where and how

**Controller** `app/controllers/openid_connect/introspect_controller.rb` — same skeleton as
`TokenController` (`skip_session_load`, `skip_session_expiration`, no CSRF), gated by
`check_or_render_not_found -> { IdentityConfig.store.token_exchange_enabled }`. **Form** `app/forms/openid_connect_introspect_form.rb`:

```ruby
class OpenidConnectIntrospectForm
  include ActiveModel::Model

  def submit
    @caller = ResourceServerAuthenticator.new(client_assertion, audience: introspect_url).call
    return FormResponse.new(success: false, errors: { client_assertion: ['invalid_client'] }) unless @caller

    @token = TokenExchangeToken.find_by(token_digest: Digest::SHA256.hexdigest(token.to_s))
    @active = active?
    FormResponse.new(success: true, extra: { active: @active, resource: @caller.identifier })
  end

  def http_status = @caller ? :ok : :unauthorized

  def response
    return { active: false } unless @active
    {
      active: true,
      aud: @token.resource_server.identifier,
      scope: @token.scope,
      sub: agency_sub,
      act: { sub: @token.service_provider.issuer },
      client_id: @token.service_provider.issuer,
      acr: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      iat: @token.created_at.to_i,
      exp: @token.expires_at.to_i,
      delegation_id: @token.grant.delegation_id,
    }
  end

  private

  def active?
    @token.present? &&
      @token.revoked_at.nil? && @token.expires_at.future? &&
      @token.resource_server_id == @caller.id &&
      @token.grant.valid_now? &&
      [@token.resource_server, @token.grant.token_exchange_scope,
       @token.resource_server.service_provider, @token.service_provider].all?(&:active?) &&
      @token.user.suspended_at.nil?
  end

  def agency_sub
    AgencyIdentityLinker.for(
      user: @token.user,
      service_provider: @token.resource_server.service_provider,
      skip_create: false,
    ).uuid
  end
end
```

**`ResourceServerAuthenticator`** (`app/services/resource_server_authenticator.rb`) extracts the
RFC 7523 check from `OpenidConnectTokenForm#validate_client_assertion`, adds
`required_claims: %w[exp jti iss sub aud]`, a `jti` set in Redis with a 5-minute TTL, and an
`exp - iat <= 300` bound. Share it with the exchange and refresh forms (for service providers) by parameterizing the
key source.

*As built:* the authenticator first reads `iss`/`sub` **unverified** to choose whose certificates to try
(every certificate on the record, so key rotation does not break callers), pins RS256, verifies the
signature *before* touching the `jti` replay cache (so an anonymous party cannot burn a legitimate
caller's `jti` values), and treats `exp` as required with `exp − iat ≤ 300 s` (or `exp − now` when `iat`
is absent). The existing authorization-code form is left untouched so today's SPs are unaffected; its
looser checks are a separate hardening decision.

**Rate limiting:** `RateLimiter.new(target: @caller.identifier, rate_limit_type: :introspection_per_resource_server)`.

**`AccessTokenVerifier`.** While here, fix a pre-existing gap: it MUST refuse identities with
`deleted_at` set. Today a revoked connection's token works at `userinfo` for as long as the session
lives. Do **not** add an "SP must be active" check here: the authorize endpoint already refuses
inactive service providers before any token exists, the change would alter `userinfo` behavior for
existing integrations mid-session, and the test suite's SP factory defaults to `active: false`, so
the check broke every existing `userinfo` spec when tried (learned during implementation; the rule
"do not change what works today" wins over the marginal hardening).

### 6.3 What the resource server must do

Login.gov cannot enforce these; they belong in the agency integration guide. The design makes
skipping them pointless: an opaque token gives the API no user identity unless it introspects.

1. Register (ONB-2) and hold the matching private key.
2. Sign a fresh RFC 7523 assertion per introspection call (`iss`/`sub` = identifier, `aud` =
   introspection URL, unique `jti`, `exp` ≤ 5 min).
3. Introspect every delegated token, or trust a cached `active: true` for at most the published
   window (INT-8). Fail closed on error or unreachability.
4. Enforce `scope` against the endpoint called. Login.gov decides which *API*; the agency decides
   which *endpoints within it*.
5. Treat `act` as delegated access and apply agency policy (for example, read-only for service providers).
   Otherwise handle the user exactly as after a direct sign-in: the identity claims in the introspection
   response (INT-10) have the same names and formats as `userinfo`, so the same code consumes them. Do
   not call `userinfo` with a delegated token; it is refused.
6. Never accept a Login.gov `id_token` as proof of delegation.
7. Refuse any JWT-shaped bearer (three segments carrying `iss` and `aud`) before calling Login.gov:
   delegated tokens are opaque, so a JWT can only be an ID token or a forgery.
8. Read `act` on every active response and, when it is present, treat the call as delegated access by
   `act.sub` (log it, join it to Attempts events, apply any third-party policy). Do **not** reject a
   token solely because `act` is absent: an API that also accepts non-delegated tokens has legitimate
   tokens without it. Login.gov's introspection endpoint answers only for delegated tokens, so `act` is
   always present in *its* active responses (INT-4); an API that accepts nothing else MAY log a missing
   `act` as an anomaly.
9. Cache only `active: true` results, keyed by the token's SHA-256 (never the token), for the shorter
   of the published window (INT-8) and the token's `exp`.
10. Fail closed (HTTP 503) when discovery does not advertise `introspection_endpoint`, so an API cannot
    silently run against an IdP with the feature off.
11. When the active response carries `cnf.jkt`, require the `DPoP` authorization scheme and verify the
    `DPoP` proof on **every** request (RFC 9449 §4.3, §7.1): `typ`, allowed `alg`, public-only `jwk`,
    signature, `htm` and `htu` equal to this request, `iat` within the acceptance window, `jti` unseen,
    `ath` equal to the SHA-256 of the presented token, and the `jwk` thumbprint equal to `cnf.jkt`. Refuse a
    bound token presented as `Bearer`, and an unbound token presented as `DPoP`, with `401` and a
    `WWW-Authenticate: DPoP algs="ES256 RS256"` challenge. Verify the proof even when the introspection
    result is cached: the cache answers "is the token good", the proof answers "is this caller the holder".
    SAML consumers apply the same rule when the assertion carries a `dpop_jkt` attribute, hashing the
    base64url assertion as presented for `ath`.

*The reference resource server (§14.4) implements items 7–10;* they were found while building it and
belong in every agency integration.

**Amended 2026-10-09 (D37).** Items 3 and 9 are superseded: there is no published window and no caching
of `active: true`. The resource server introspects on every request, so a revocation takes effect at the
next request. Item 11's rule about verifying the proof on every request is unchanged.

### 6.4 Amendments of 2026-10-09 (introspection interview)

Where a row below conflicts with §6.1–§6.3, this subsection governs. Decided with the product owner on 2026-10-09 (implementation plan D26, D34–D37).

| ID | Requirement |
|---|---|
| **INT-1** (amend) | Two kinds of caller authenticate. A **resource server** authenticates with `private_key_jwt` as before. The **public-client service provider** that holds a delegated token MAY introspect it with `client_id` and a DPoP proof (RFC 9449 §4.3) whose `ath` is the hash of the `token` parameter and whose key thumbprint equals the token's `cnf.jkt`; no client assertion. A caller that is neither, or whose assertion or proof fails, receives HTTP 401 `invalid_client`. |
| **INT-2** (amend) | The full active response is returned only when the caller is the token's resource server. When the caller is the service provider named in `act.sub` and the proof binds to the token, the response is the limited form of INT-14, under the same validity conditions. |
| **INT-3** (unchanged) | An authenticated caller asking about a token it is neither the audience of nor the bound holder of receives exactly `{"active": false}`. |
| **INT-5** (amend) | `sub` is the user's `AgencyIdentity` uuid for the resource server's owning agency, created at first introspection if the user has never used that agency (`AgencyIdentityLinker` creates the `agency_identities` row only); no `identities` row for the agency SP is created or read (EXC-5). |
| **INT-7** (replace) | Introspection is not rate-limited per resource server and never answers HTTP 429. Volume and error rate per caller are logged and monitored against configurable alert thresholds (§10 as amended); runaway-caller protection is the infrastructure layer's. |
| **INT-8** (replace) | Login.gov publishes no cache window. The integration guide states that a resource server introspects on every request and that revocation is therefore seen at the next request. `token_exchange_introspection_cache_seconds` is not introduced. |
| **INT-9** (amend) | The 429 clause is withdrawn with INT-7; `token_type` in the active response and HTTP 401 `invalid_client` for failed authentication stand. |
| **INT-10** (amend) | After the service provider's session has ended, the active response to the resource server carries `sub`, `delegation_id` and `email` (with `email_verified` and `all_emails` as `userinfo` does), the token members of INT-4 and `attributes: "identifiers_only"`; no other identity claim. While the session is live the response carries the agency's bundle as written. |
| **INT-14** | The active response to the **service provider** (INT-1 as amended) carries `active`, `exp`, `iat`, `aud`, `scope`, `delegation_id`, `token_type`, `cnf`, `iss` and the service provider's own pairwise `sub` (the value its `id_token` carries), plus any claim the application lists in `sp_shareable_attributes` (an application-level list, empty by default, maintained with the consent content). It carries no `act`, no `auth_time`, no `ial`/`aal` and no identity attribute from the agency's bundle. |
| **INT-15** | Introspection reads the live token from Redis by the digest of the `token` parameter (§5.2 as amended); a missing entry is `active: false`. The issuance record is not consulted for validity. |
| **INT-1** (amend 2026-10-10) | As built: a resource server whose assertion fails receives 401 `invalid_client`; the public-client service provider whose proof is missing or fails on its own terms receives 401 `invalid_dpop_proof` with `WWW-Authenticate: DPoP algs="ES256 RS256"`; a request with no credential, or a `client_id` that is not a public client approved for delegation, receives 200 `{"active": false}` (D62). |
| **INT-3** (amend 2026-10-10) | The same `{"active": false}` is given when the service provider's proof verifies but its key is not the one the token is bound to; the key comparison is part of entitlement, never a reason given to the caller (D62). |
| **INT-4** (amend 2026-10-10) | `jti` is the hex SHA-256 digest of the token, the key the live entry is stored under; "derived from the stored digest, never the digest itself" is withdrawn (D63). `acr` carries the identity-assurance context and `aal` the authentication-assurance context as `userinfo` reports them. |
| **INT-10** (amend 2026-10-10) | The member that states the session state is `session_live`: `true` with the agency's bundle, `false` with `sub`, `delegation_id` and `email` (plus `email_verified`, and `all_emails` when bundled). `attributes: "identifiers_only"` is not emitted and INT-12's rule for when it appears is replaced: `session_live` is always present in the resource server's active response (D63). |

**Why INT-1/INT-14.** A browser-based service provider needs to tell an expired or revoked token from a failing agency API, and the token string tells it nothing (EXC-20). Letting it introspect its own token, bound by the proof to the key only it holds, answers that without releasing the agency's attributes; a party holding the token without the key cannot use the endpoint as an oracle. The response is limited to what the service provider's own sign-in already conveys plus what the agency chooses to share.

**Amended 2026-10-09 (D59).** `/api/openid_connect/introspect` carries the token endpoint's CORS treatment (§5.3 as amended) so the service provider's own introspection from the browser works; the resource server's introspection is server-to-server and unchanged.

**As built, 2026-10-10 (`delegated-access-introspection`).** Routes: `POST /api/openid_connect/introspect` and OPTIONS, `OpenidConnect::IntrospectController` and `OpenidConnectIntrospectForm`, 404 while `token_exchange_enabled` is off; the `Rack::Cors` resource in `config/application.rb`. Callers: `ResourceServerAuthenticator` (`key_source: :resource_server`, `aud` the introspect URL) for the agency; `client_id` naming a `pkce` record approved for delegation plus a `DpopProofVerifier` check of the `DPoP` header for POST to the introspect URL with `ath` over `token` for the service provider; 401 for a failed credential, `{"active": false}` for no credential, a wrong-key proof or a caller that is neither (INT-1, INT-3 as amended). Validity: `DelegatedTokenStore.read`, `expires_at` in the future, user present and not suspended, `TokenExchangeGrant#valid_now?`, `TokenExchangeResourceServer#usable?`, the service provider still `delegation_service_provider?`; entitlement by `resource_server_id`, or by `service_provider_id` with `dpop_jkt` equal to the proof thumbprint. Members: `active`, `iss`, `aud`, `scope`, `client_id`, `delegation_id`, `token_type`, `iat`, `exp`, `cnf.jkt` when bound; for the agency also `sub` (`AgencyIdentityLinker.for(user:, service_provider: application, skip_create: false)`, no `identities` row), `act.sub`, `jti` (token digest, INT-4 as amended), `acr`, `aal`, `auth_time` (`identities.last_authenticated_at`, else `iat`), `session_live` and the claims `DelegatedTokenClaims` derives from the application's `attribute_bundle` through `OpenidConnectAttributeScoper` and `OpenidConnectClaimsFormatter` (the formatter userinfo now uses too); for the service provider `sub` as its own `id_token` carries it and the claims for `service_providers.delegation_sp_shareable_attributes` (migration `20261009110000`, string array, default empty) intersected with the bundle (INT-14). `email` is the identity's shared address (INT-13). Analytics `openid_connect_introspect`. Userinfo: `AccessTokenVerifier` accepts the `DPoP` scheme, requires a proof (`htm`, `htu`, `ath`, thumbprint equal to `identities.dpop_jkt`) for a bound identity and refuses its bearer presentation with `WWW-Authenticate: DPoP algs="ES256 RS256"`; `OpenidConnect::UserInfoController` and `OpenidConnect::DocumentImagesController` are wired the same way; bearer identities are unchanged; delegated tokens are refused with or without a proof (EXC-6, EXC-18, INT-16).

### 6.5 Amendments of 2026-10-09 (document images and encrypted userinfo)

Decided with the product owner on 2026-10-09 (implementation plan D49, D50; functional requirements §11 as amended). Nothing here changes introspection.

| ID | Requirement |
|---|---|
| **INT-16** | Document images and document metadata (the `document_images` attribute set inherited from `sbx-taigrr`) are never released by introspection or in a SAML assertion, whatever the agency's bundle says; they are reachable only at `/api/openid_connect/userinfo` with the service provider's own access token, and delegated tokens are refused there (EXC-6, EXC-18). |
| **DOC-1** | The direct-service-provider document-images feature (`document_images` scope, `document_images_sharing_service_providers` allow-list, biometric consent checkbox on the completions screen, `document_artifacts` store, download endpoint, 90-day expiry job) is kept as built and is enabled (`document_images_sharing_enabled: true`) in the sandbox only; it is off in every other environment. The Department of State is registered there as a direct service provider on the allow-list (§14.5 as amended). No delegated channel for images is built this phase. |
| **UINF-1** (planned) | Encrypted userinfo responses: when the service provider that the presented access token belongs to has a registered encryption certificate and `userinfo_encrypted_response_alg`/`userinfo_encrypted_response_enc` (OpenID Connect Core 5.3.2), the whole userinfo attribute bundle is returned as a JWE (RFC 7516) encrypted to that certificate. The key is selected from the token's own service provider record, never from the request. Applies to the Department of State's attributes first. Planned 2026-10-09, not built this phase; no code, migration or configuration key is added for it. |

---

## 7. Refresh tokens and revocation

### 7.1 Requirements

| ID | Requirement |
|---|---|
| **REF-1** | The exchange response (EXC-7) MUST include a `refresh_token` (RFC 8693 §2.2.1 permits it). Refresh tokens MUST be issued only by the exchange, only for delegated tokens. |
| **REF-2** | Service providers refresh at `POST /api/openid_connect/token` with `grant_type=refresh_token` (RFC 6749 §6), authenticating with `private_key_jwt`. The assertion MUST be from the same service provider that performed the exchange, or the request fails with `invalid_grant`. |
| **REF-3** | The refreshed access token MUST have the same `aud`, `scope`, `act`, grant and `delegation_id` as the family. A `scope` parameter, if present, MUST equal the family's scope exactly or the request fails with `invalid_scope`. A `resource` parameter MUST be rejected with `invalid_request`. A family bound to a key (EXC-9) stays bound: the refresh MUST carry a `DPoP` proof signed by that key, and the refreshed token inherits the binding; a missing proof or a different key fails with `invalid_dpop_proof` without rotating the family. A proof on an unbound family binds the refreshed token to the proof key (RFC 9449 §5); the earlier access token remains a bearer token until it expires. |
| **REF-4** | Every refresh MUST rotate the refresh token (RFC 9700 §4.14.2). Presenting a refresh token that has already been rotated MUST revoke the entire family (all access and refresh tokens from that exchange) and emit `delegated-access-revoked` with `reason: refresh_token_reuse`. |
| **REF-5** | Access tokens live **15 minutes** (`token_exchange_access_token_ttl_seconds`, default 900). The refresh family has an **absolute, non-sliding** lifetime of **12 hours** from the exchange (`token_exchange_refresh_token_ttl_seconds`, default 43200), further capped by the grant: never later than `remember_until`, or 12 hours after exchange for a non-remembered grant. A per-service-provider override MAY lower, never raise, these. |
| **REF-6** | Delegated token validity MUST NOT depend on the user's Rails session. Sign-out at Login.gov does not revoke delegated families; account suspension or deletion does; grant revocation does. |
| **REF-7** | Refresh tokens MUST be stored hashed (SHA-256). The plaintext exists only in the response. |
| **REF-8** | Login.gov MUST expose `POST /api/openid_connect/revoke` per RFC 7009 so a service provider can revoke a refresh token (and its family) when the user's task ends early. |
| **REF-10** | Rotation MUST run under a database row lock on the presented refresh token, so two concurrent refreshes with the same token cannot both succeed: the second sees `rotated_at` set and is treated as reuse. A family that is already revoked MUST NOT be revoked or reported again on a further replay. |
| **REF-11** | A `resource` parameter on refresh MUST be refused with `invalid_request` rather than ignored: the audience is fixed by the family, and a service provider that wants another API must exchange again. |
| **REF-12** | The refreshed access token's `expires_at` MUST be the earlier of "now + access TTL" and the family's `family_expires_at`, so no access token outlives its family. |
| **REF-9** | A refresh MUST NOT write a billing row (§9) and MUST emit `delegated-access-token-refreshed` (§8). |

**Why REF-10.** Without the lock, two near-simultaneous refreshes (a retrying client, or a client and an
attacker) could both read `rotated_at: nil`, both mint, and reuse detection would never fire.

**Why 12 hours.** NIST SP 800-63B §4.2.3 requires AAL2 sessions to reauthenticate at least once
every 12 hours regardless of activity. Bounding delegated access to the same ceiling means a
service provider never holds the user's identity longer than the user's own session would have been
trusted. It is long enough for an unattended agent task; anything longer should be a new consent.

**Why REF-6.** Today every Login.gov token dies with the browser session (`IdTokenBuilder#ttl`
returns the session's Redis TTL; `session_timeout_in_seconds` is 900). That defeats the purpose
of delegation: an agent working for the user for an hour would need the user to keep the
service provider's tab open. The user has explicitly delegated for a bounded window and can see and end it
on the account page (ACC-1), so the session is no longer the right boundary.

**Why REF-4.** A refresh token is long-lived and valuable. Rotation plus reuse detection means a
stolen-and-replayed token costs the attacker the access instead of extending it, because
whichever party uses the old token second triggers family revocation.

### 7.2 Table

**`token_exchange_refresh_tokens` — new table**

| Column | Type | Comment | Purpose |
|---|---|---|---|
| `id` | bigint | | |
| `token_digest` | string, unique | sensitive=false | SHA-256 of the refresh token |
| `family_id` | string, indexed | sensitive=false | Same as `token_exchange_tokens.refresh_family_id` |
| `grant_id` | FK → `token_exchange_grants` | sensitive=false | |
| `resource_server_id`, `service_provider_id`, `user_id` | FKs | sensitive=false | Copied from the family for fast checks |
| `scope` | string | sensitive=false | Copied from the family (REF-3) |
| `family_expires_at` | datetime | sensitive=false | Absolute end of the family (REF-5) |
| `rotated_at` | datetime, nullable | sensitive=false | Set when this token is used; non-null means "already used" |
| `revoked_at`, `revocation_reason` | datetime, string | sensitive=false | |
| timestamps | | sensitive=false | |

### 7.3 Where and how

**Refresh form** `app/forms/openid_connect_refresh_token_form.rb`. Do not bolt this onto
`OpenidConnectTokenForm`, which assumes an authorization code looked up by `session_uuid`.
`TokenController#build_form` (§5.3) already dispatches `grant_type=refresh_token` to it.

```ruby
class OpenidConnectRefreshTokenForm
  include ActiveModel::Model

  validate :validate_client_assertion       # service provider private_key_jwt
  validate :validate_refresh_token          # exists, not revoked, family not expired
  validate :validate_same_service provider            # REF-2
  validate :validate_scope_and_resource     # REF-3
  validate :validate_rate_limit

  def submit
    @success = valid?
    return FormResponse.new(success: false, errors:) unless @success

    TokenExchangeRefreshToken.transaction do
      if @rt.rotated_at.present?                      # REF-4: reuse detected
        TokenExchangeRefreshToken.revoke_family!(@rt.family_id, reason: 'refresh_token_reuse')
        AttemptsApi::DelegatedEvents.revoked(@rt, reason: 'refresh_token_reuse')
        errors.add(:refresh_token, 'invalid_grant', type: :invalid_grant)
        @success = false
        raise ActiveRecord::Rollback
      end
      @rt.update!(rotated_at: Time.zone.now)
      @minted = TokenExchangeToken.mint_from_family!(@rt)        # copies aud/scope/act/grant, new expires_at
      @new_rt = TokenExchangeRefreshToken.issue_for(@minted)     # same family_id, same family_expires_at
      AttemptsApi::DelegatedEvents.token_refreshed(@minted)
    end
    FormResponse.new(success: @success, errors:)
  end
end
```

`TokenExchangeRefreshToken.issue_for(minted)` sets `family_expires_at` to
`[exchange_time + refresh_ttl, grant.remember_until || exchange_time + refresh_ttl].compact.min`
and stores only the digest.

**Revocation endpoint** `app/controllers/openid_connect/revoke_controller.rb` +
`app/forms/openid_connect_revoke_form.rb`: authenticate the service provider; look up the token by digest
in both tables; if it belongs to this service provider, revoke the family with reason `client_revoked`.
Per RFC 7009 §2.2, return HTTP 200 even if the token is unknown.

*As built:* the only non-200 answer is 401 `invalid_client` for a failed client assertion; a token that is
unknown, already revoked, or belongs to another service provider still yields `200 {}` so the endpoint
never confirms a token's existence. A revocation of a live family emits `delegated-access-revoked` with
`reason: client_revoked`.

### 7.4 Session decoupling

- `TokenExchangeToken` validity is `expires_at` and `revoked_at` only (INT-2). Do not consult
  `OutOfBandSessionAccessor` for delegated tokens.
- `User#suspend!`/deletion paths (`app/models/user.rb`, `Users::DeleteController`) MUST call
  `TokenExchangeRefreshToken.revoke_all_for_user!(user, reason: 'account_status')`.

### 7.5 Cascading revocation

`TokenExchangeGrant#revoke!` MUST revoke every `token_exchange_tokens` and
`token_exchange_refresh_tokens` row with that `grant_id`. Kill switches (`active: false` on a
scope, resource server or SP) are checked at introspection and refresh time, so no cascade is
needed for them; flipping the flag is enough.

**Amended 2026-10-09 (D26).** `TokenExchangeGrant#revoke!` reads the grant's Redis index set
(`delegated_tokens:grant:<grant_id>`), deletes every live token entry it lists, marks the grant's issuance
rows and refresh tokens revoked in Postgres, and removes the set. Family revocation (REF-4, REF-8) does the
same through `delegated_tokens:family:<family_id>`. Kill switches are unchanged.

### 7.6 Amendments of 2026-10-09 (token lifecycle interview)

Where a row below conflicts with §7.1–§7.5, this subsection governs. Decided with the product owner on 2026-10-09 (implementation plan D26, D27, D32, D33, D37).

| ID | Requirement |
|---|---|
| **REF-4** (amend) | Reuse of a rotated refresh token revokes the family (§7.5 as amended), emits `delegated-access-revoked` with `reason: refresh_token_reuse` to the agency (ATT-7) and logs an analytics event carrying the service provider, resource server and family id, so operations see the reuse without reading agency events (RFC 9700 §4.14.2). |
| **REF-5** (amend) | The family's absolute lifetime is 12 hours (`token_exchange_refresh_token_ttl_seconds`) counted from the **first exchange**, for every grant whether remembered or not, and never later than the grant's `remember_until`. A non-remembered grant's family does not end with the Login.gov session. A resource server's `max_family_seconds` and a service provider's override MAY lower the family lifetime, and a resource server's `max_access_token_seconds` MAY lower the access token lifetime; none may raise them. |
| **REF-7** (confirmed) | Refresh tokens are Postgres rows storing the SHA-256 digest only (`token_exchange_refresh_tokens`, §7.2 unchanged); the family's durability is what makes reuse detection and the account page's "token active" state reliable. |
| **REF-13** | The refresh grant is not rate-limited per service provider (`refresh_per_sp_*` is not introduced). Refresh volume and error rate per service provider are monitored against configurable alert thresholds (§10 as amended). |
| **REF-14** | Storage split: live access tokens and SAML assertions in Redis (keyed by digest, TTL equal to the lifetime, indexed per grant and per family); refresh tokens and issuance records in Postgres. A refresh writes a new Redis entry and a new issuance row and adds the new digest to the family's index set; the earlier access token keeps its own TTL. |

**Why REF-5 (amend).** Ending a non-remembered grant's family with the Login.gov session would make the
service provider's unattended work depend on a browser tab, the problem REF-6 exists to remove; a 4-hour
default was considered and rejected because the 12-hour AAL2 ceiling is the bound the design already
justifies, and agencies that need less can set it per resource server.

**Amended 2026-10-09 (D59).** `/api/openid_connect/revoke` carries the token endpoint's CORS treatment (§5.3 as amended) so a public-client service provider can revoke from the browser with its DPoP proof; a confidential client's `private_key_jwt` revocation is unchanged.

**As built, 2026-10-10 (`delegated-access-token-lifecycle`).** Table `token_exchange_refresh_tokens` (migration `20261009100800`, model `TokenExchangeRefreshToken`) differs from §7.2 in three places: `expires_at` is the family's absolute end (the name `family_expires_at` is not used), `used_at` records every presentation including a reuse attempt while `rotated_at` marks a spent token, and `token_exchange_token_id` (the issuance record the refresh token was issued with) and `dpop_jkt` (the family's key binding) are added. `TokenExchangeRefreshToken.family_end` is the lowest of `token_exchange_refresh_token_ttl_seconds` (43200), `token_exchange_resource_servers.max_family_seconds` (migration `20261009100900`) and `service_providers.delegation_max_family_seconds` (migration `20261009101000`) from the exchange, never past `remember_until` (REF-5 as amended; the clock starts at the exchange that opens the family, E99). `TokenExchangeToken.lifetime_seconds_for` caps every access token at the family end as well as at `max_access_token_seconds`. The exchange response carries `refresh_token` and `refresh_token_expires_in`, both measured from the issuance instant. `OpenidConnectRefreshTokenForm` (dispatched from `OpenidConnect::TokenController#build_form` on `grant_type=refresh_token`) authenticates through the shared `DelegatedAccessClientHandling` concern, verifies a public client's proof (no `ath`) before the lookup, refuses `resource` outright and `scope` unless equal to the family's, rotates under `SELECT … FOR UPDATE`, revokes the family with reason `approval_lapsed` when the approval no longer stands, refuses without revoking when a kill switch is off, and on reuse revokes the family with reason `refresh_token_reuse` (`TokenExchangeRefreshToken.revoke_family!`, through `DelegatedTokenStore.revoke_family`), logs `openid_connect_token_refresh` and `delegation_refresh_token_reuse`, and calls the `report_family_revoked` seam that §8 fills in (REF-4 as amended). `POST /api/openid_connect/revoke` (`OpenidConnect::RevokeController`, `OpenidConnectRevokeForm`): a refresh token ends its family with reason `client_revoked`; a delegated access token is removed alone (`DelegatedTokenStore.revoke_token`) and its issuance record marked `client_revoked`; the client's own sign-in token, an unknown, foreign, revoked or differently bound token is not acted on; every authenticated case is 200 `{}`; a missing `token` is 400 `invalid_request`, a failed credential 401 `invalid_client`; the `Rack::Cors` resource of the D59 amendment is in `config/application.rb`; 404 while `token_exchange_enabled` is off. Cascades (§7.4, §7.5 as amended): `TokenExchangeGrant#revoke!` and `#transfer_live_tokens_to!` cover the refresh rows; `TokenExchangeGrant.revoke_all_for_user!` is called by `User#suspend!` (`account_suspended`), `Users::DeleteController` and `AccountReset::DeleteAccount` (`account_deleted`); the reason `account_status` of §7.4 is not used; sign-out touches nothing. Fixture: the records API in `config/delegated_access.localdev.yml` carries `max_family_seconds: 14400`.

---

## 8. Fraud signals: Attempts API delivery to target agencies

### 8.1 Background (how the Attempts API works today)

- Events are Security Event Tokens (RFC 8417), encrypted per SP with JWE to the SP's
  `attempts_public_key`, stored in Redis by hour under the SP's issuer, and polled by the SP
  (RFC 8936) at `POST /api/attempts/poll`. Discovery is `/.well-known/ssf-configuration`.
- `AttemptsApi::Tracker` records an event only when `current_sp.attempts_api_enabled?` **and**
  the SP passed `attempts_api_session_id` (or `tid`) in the authorize request
  (`ApplicationController#attempts_api_enabled_for_session?`). Events always go to `current_sp`.
- `subject.session_id` in every event is the **SP-supplied** session ID
  (`docs/attempts-api/schemas/events/shared/Subject.yml`: "Matches the session ID passed in
  from the service provider"). `unique_session_id` is the Login.gov-generated one.
- Historical `idv-*` events are stored in encrypted document storage, loaded into the session by
  `AttemptsApi::Cacher` on password sign-in, and released once per SP from
  `SignUp::CompletionsController#send_historical_events`, guarded by
  `UserProofingEvent#already_sent_to_sp?`.
- `login-completed` fires at handoff (`OpenidConnect::AuthorizationController#track_events`),
  after the consent screen. There is no consent event today.

### 8.2 The problem delegation creates

The user signs in and consents at the service provider. Every event is attributed to the service provider, and for
a service provider not enrolled in the Attempts API the sign-in events are **never recorded at all**. The
target agency, which will act on this identity, sees nothing: no sign-in, no MFA, no device, no
IP, no verification history. This is the data agencies use to stop account takeover and
synthetic-identity fraud, and delegation would remove it exactly where fraud is most attractive.

### 8.3 Requirements

| ID | Requirement |
|---|---|
| **ATT-1** | When a delegation-enabled service provider's authorization request carries `token_exchange:*` values, Login.gov MUST capture the sign-in session's Attempts events (sign-in, MFA, rate-limit, `idv-*`) into a KMS-encrypted buffer in the user session, **regardless of whether the service provider is enrolled** in the Attempts API. The buffer lives only as long as the session. |
| **ATT-2** | At consent, for **each approved** delegation scope whose resource server's `attempts_service_provider` is enrolled in the Attempts API, Login.gov MUST: (a) create the user's `AgencyIdentity` for that agency if missing; (b) deliver the buffered events re-mapped for that agency; (c) deliver a new `delegated-access-consented` event; (d) release historical `idv-*` events to that agency under the existing once-per-SP rule. |
| **ATT-3** | Re-mapping MUST set `user_uuid` to the agency's `AgencyIdentity` UUID, remove `google_analytics_cookies`, keep `application_url` (the service provider's redirect URI), keep IP, user agent, device ID and all event-specific fields, and add a `delegation_id` property. `subject.session_id` MUST remain the value the service provider supplied in `attempts_api_session_id` (or null), per the published schema. |
| **ATT-4** | Nothing MUST be delivered to, and no `AgencyIdentity` MUST be created for, an agency the user declined. `user_uuid` resolution MUST therefore be deferred until consent (today `Tracker#agency_uuid` creates the `AgencyIdentity` as a side effect). |
| **ATT-5** | When consent is skipped because remembered grants cover the request (CON-5), ATT-2 MUST run at handoff instead, and the `delegated-access-consented` event MUST carry `remembered: true` and the original `consented_at`. |
| **ATT-6** | `login-completed` at handoff MUST also be delivered to each approved agency, re-mapped. |
| **ATT-7** | Each exchange MUST emit `delegated-access-token-issued`; each refresh `delegated-access-token-refreshed`; each grant or family revocation `delegated-access-revoked` with a `reason`. These are written directly with `AttemptsApi::AttemptEvent` + `AttemptsApi::RedisClient` to the agency's issuer, since `attempts_api_tracker` is unavailable in API controllers (`skip_session_load`, no `current_sp`). They carry no IP or user agent unless the controller captures the service provider server's and labels it as such. |
| **ATT-8** | While the service provider's browser session is live, re-authentication, MFA change, logout, timeout and rate-limit events MUST also be delivered to each approved agency. |
| **ATT-9** | Introspection MUST return `delegation_id` (INT-4) so the agency can join API calls to these events. |
| **ATT-11** | The delegation context and the event buffer MUST live at the Rails session root, not in the Devise user session, and each buffered event MUST be KMS-encrypted individually. Buffering MUST NOT change `Tracker#track_event`'s return value or create an `AgencyIdentity` at the service provider's agency. |
| **ATT-12** | Candidate agencies are the requested scopes' resource servers' Attempts recipients that are enrolled at authorize time; a request whose targets are all unenrolled captures nothing. The buffer persists for the whole session and is delivered at most once per agency; an agency approved later in the session receives the full session history, an agency re-approved receives a new consented event only. |
| **ATT-13** | The remembered path emits one `delegated-access-consented` (`remembered: true`) per authorization (per SP request id), not per session; a request already released at the consent screen is not released again at handoff. An agency whose scopes are all declined on a later screen is removed from live fan-out and receives nothing further. A later authorize request without delegation scopes leaves previously approved agencies receiving live events for the rest of the browser session. |
| **ATT-14** | `delegation_id` in events is the agency's earliest approved grant's id (the same choice the exchange and introspection make), so events and introspection agree; re-mapped copies and released historical `idv-*` events carry both `delegation_id` and `actor_issuer`. |
| **ATT-15** | Delegated historical release requires `historical_attempts_api_enabled` and a verified user, but not that the service provider's request be an IdV request: a delegation request is always identity-proofed, and the agency did not make the request. |
| **ATT-16** | Every event schema under `docs/attempts-api/schemas/events` MUST have a `TrackerEvents` method whose keyword parameters equal the event's properties (the compiled OpenAPI bundle is checked by `tracker_events_spec.rb`), so the four delegated events have such methods even though `DelegatedEvents` writes them directly; the consented event carries `consented_at` (epoch seconds). |
| **ATT-17** | For delegated delivery, an agency counts as **enrolled** only if it is listed in the Attempts API configuration **and** a usable public key exists to encrypt events to (an explicit key in that configuration, or the agency SP's certificate). An agency listed without a usable key is treated as not enrolled and receives nothing; no error is raised and the user is not affected. The direct sign-in flow's existing behavior is unchanged. |
| **ATT-10** | New event types and the `delegation_id` property MUST be added to `app/services/attempts_api/tracker_events.rb` and to the OpenAPI schemas under `docs/attempts-api/schemas/events/` (a new `DelegationEvents.yml` group referenced from `AllEvents.yml`; `delegation_id` in `shared/EventProperties.yml`). |
| **ATT-18** | Delegated events are delivered through the existing poll endpoint (`POST /api/attempts/poll`, RFC 8936) and inherit its acknowledge-to-drain contract: the endpoint deletes exactly the events whose keys a caller lists in the request's `ack` array, then returns the events that remain as `sets`. Unacknowledged events stay available until `attempts_api_event_ttl_seconds` (about an hour) expires. A polling agency MUST acknowledge each event once it is durably stored — by sending that event's key in `ack` on a later poll — so the read pointer advances and subsequent polls return only new events; a caller that never acknowledges re-receives the whole retention window on every poll. |

**Why ATT-18.** Surfaced in the live end-to-end run: the reference agency viewers poll without
acknowledging, so events from every earlier scenario were still in the buffer and the "one delegation
per sign-in" viewer showed many sign-ins at once. The delivery contract itself is unchanged from the
existing Attempts API; this row only records that delegated delivery inherits it and that a production
agency integrator must acknowledge to drain. The reference viewers acknowledge nothing on purpose (so a
human refreshing the page still sees the last hour), and the end-to-end harness empties the store between
scenarios rather than acknowledging, which keeps each scenario's assertions independent.

**Why ATT-17.** Found in the first live run: an agency SP row seeded before its certificate file
existed was listed in the Attempts configuration but had no public key; `attempts_public_key` raised and
the consent screen returned HTTP 500. The same condition would fail the direct handoff today, so it is a
pre-existing fragility, not a delegation bug. The correct reading is that such an agency is simply not
onboarded to the Attempts API and must get no events; an explicit predicate expresses that, where a blanket
rescue would have hidden real bugs.

**Why ATT-11.** Sign-in events (failed password, rate limits) fire before a Devise user session exists,
and the whole-session `SessionEncryptor` refuses plaintext containing keys such as `email`, which sign-in
events carry; per-event encryption also makes an append one KMS call. Callers rely on `track_event`'s
existing return semantics, and a non-enrolled SP never created an `AgencyIdentity` before.

**Why ATT-12/ATT-13.** Delivering the buffer once per agency avoids duplicates without losing sign-in
history for agencies added later; each handoff is a distinct authorization the agency should see; the IdP
session spans service providers and "live session" is the boundary the requirement names.

**Why ATT-3 keeps `subject.session_id` as the SP's value.** Agencies join Attempts events to their
own sessions on that field. Putting a Login.gov-minted ID there would orphan those joins and
break the published contract. A separate `delegation_id` gives the agency a correlation key
without changing the meaning of an existing field.

**Why ATT-2(a).** `HistoricalAttemptEvent#transformed_metadata` re-maps `user_uuid` with
`AgencyIdentityLinker.for(..., skip_create: true)`, which returns nil — and then raises on
`.uuid` — when no `AgencyIdentity` exists. Before delegation, the target agency has never seen
this user, so none exists.

**Why the disclosure is not on the consent screen.** Attempts API data sharing with relying
parties is already covered by Login.gov's Privacy Impact Assessment; the consent screen is about
the delegation itself.

**Confirmed 2026-10-09 (D38, D39).** The whole of §8 stands as written: buffering while a delegation
request is in flight (ATT-1, ATT-11), release at consent under the agency's pairwise identifier with the
consented event and the historical `idv-*` release (ATT-2), live forwarding (ATT-8), the token events
(ATT-7, with `refresh_token_reuse` as a revocation reason per REF-4 as amended) and the remembered path
with `remembered: true` on every reuse (ATT-5, ATT-13). Delivery in any shared environment stays behind
`token_exchange_enabled` pending the privacy review.

### 8.4 Where and how

- **Buffer** (`ATT-1`): in `AttemptsApi::Tracker#track_event`, when
  `session[:delegation_context]` is present, serialize the `AttemptEvent` (without `user_uuid`)
  and append it to `user_session[:delegated_attempts_buffer]`, KMS-encrypted like
  `Cacher#save`. Change `#should_track?` to return true while a delegation context with at least
  one enrolled candidate is active.
- **Delegation context** (set in `OpenidConnect::AuthorizationController` after CON-2 passes):
  the candidate agencies (resource server → `attempts_service_provider`) and a `delegation_id`
  per grant (created when the grant row is written; for candidates, generated now and carried
  into the grant).
- **Release** (`ATT-2`): new service `app/services/attempts_api/delegated_release.rb`, called from
  `SignUp::CompletionsController#update` after grants are written, and from the handoff path for
  ATT-5:

```ruby
module AttemptsApi
  class DelegatedRelease
    def initialize(user:, user_session:, grants:)  # approved grants only
      ...
    end

    def call
      grants.group_by { |g| g.token_exchange_scope.resource_server.attempts_service_provider }
            .each do |agency_sp, agency_grants|
        next unless agency_sp&.attempts_api_enabled?
        agency_uuid = AgencyIdentityLinker.for(user:, service_provider: agency_sp, skip_create: false).uuid
        delegation_id = agency_grants.first.delegation_id

        buffered_events.each { |e| write(agency_sp, remap(e, agency_uuid:, delegation_id:)) }
        write(agency_sp, consented_event(agency_grants, agency_uuid:, delegation_id:))
        release_historical(agency_sp)   # target-aware variant of send_historical_events
      end
    end
  end
end
```

- **Historical release** (`ATT-2(d)`): `Tracker.write_existing_user_events(sp:, historical_attempts:)`
  already takes an explicit SP. Extract the guard logic from
  `Idv::HistoricalAttemptsConcern#send_historic_events?` into a method that takes the agency SP
  and does not depend on `idv_requested?` for the *service provider's* request. If `Cacher#fetch` is empty
  (remember-device or PIV sign-in), release nothing and leave `already_sent_to_sp?` false.
- **Event definitions** (`ATT-7`, `ATT-10`) in `tracker_events.rb`, following the existing
  docstring style:

```ruby
# @param [String] actor_issuer the service provider
# @param [Array<String>] scopes approved delegation scope values for this agency
# @param [Array<String>] resources resource server identifiers
# @param [Boolean] remembered whether this reuses a remembered grant
# The user consented to let a service provider act for them at this agency's API(s).
def delegated_access_consented(actor_issuer:, scopes:, resources:, remembered:, **metadata)
  track_event('delegated-access-consented', actor_issuer:, scopes:, resources:, remembered:, **metadata)
end
```

- **Sample RP** (optional): `identity-oidc-sinatra`'s Attempts viewer redacts fields not in
  `ALLOWED_PLAINTEXT_KEYS` (`app.rb:28-46`); add the new fields so demos render them.
  *Learned:* besides the double `connection.post` in `#attempts_events` (§14.3), the viewer never
  `JSON.parse`d **unsigned** events (only the signed path decoded), so with
  `attempts_api_signing_enabled: false` nothing rendered. Both reference viewers fix this.

### 8.5 What the target agency must do

- Be enrolled in the Attempts API (`allowed_attempts_providers`, encryption key, poll token).
  **Existing integrations receive the existing event types with no code change.**
- Handle the four new event types and the `delegation_id` property. Any event with
  `delegation_id` or `actor_issuer` is a delegated session; its `subject.session_id` will not
  match a session the agency started.
- Join introspection's `delegation_id` to events' `delegation_id`.
- Acknowledge events once they are durably stored, by sending their keys in the next poll's `ack`
  array, so the read pointer advances and later polls return only new events (ATT-18).
  Unacknowledged events remain available until the store's retention window expires, so a poller
  that crashes before acknowledging loses nothing.

---

## 9. Billing

### 9.1 Background (how billing works today)

- `BillableEventTrackable#track_billing_events` writes an `sp_return_logs` row at the
  **handoff** back to the SP (`OpenidConnect::AuthorizationController#track_events`,
  `SamlIdpController`). Columns: `request_id` (unique), `user_id`, `issuer`, `ial` (1 or 2 from
  `IalContext#bill_for_ial_1_or_2`), `billable`, `returned_at`, `profile_id`,
  `profile_verified_at`, `profile_requested_issuer`.
- One `billable: true` row per session per SP per IAL class, tracked with `user_session` flags
  `auth_counted_<issuer>[ial1]`. Later handoffs are meant to write `billable: false` rows, but
  `request_id` is reused when the same SP re-requests in a session
  (`ServiceProviderRequestHandler`), so those rows usually collide with the unique index and
  are silently dropped by `rescue ActiveRecord::RecordNotUnique`.
- **Authentication invoicing:** `Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa` counts
  `billable = true` rows filtered by the IAA's issuers and month, **grouped by `user_id`** — a
  user is billed once per IAA per month however many rows they have.
  `TotalMonthlyAuthCounts` inner-joins `service_providers` on issuer. `Reports::DailyAuthsReport`
  left-joins it.
- **Proofing invoicing:** `NewUniqueMonthlyUserCountsByPartner` counts IAL2 billable rows per
  partner, splitting *upfront* (`profile_requested_issuer == issuer`) from *existing*. Partner
  runs are independent (`CombinedInvoiceSupplementReportV2`).
- **Issuer → IAA:** `sp_return_logs.issuer` → `integrations.issuer` (FK to `service_providers`)
  → `integration_usages` → `iaa_orders` → `iaa_gtcs` → `partner_accounts` → `agencies`
  (`IaaReportingHelper`).

### 9.2 Requirements

| ID | Requirement |
|---|---|
| **BIL-1** | Each successful exchange MUST write an `sp_return_logs` row for the target agency, with `issuer` = the resource server's `billing_issuer`, `ial` derived as for direct access (2 when the user is verified and the service provider asserted IAL2 or IALmax — never the raw stored `ial`, which can be 0), `returned_at` = exchange time, and the profile columns as `BillableEventTrackable#create_sp_return_log` sets them. |
| **BIL-2** | `billable` MUST be `true` for the first exchange per **grant set** (the service provider identity's current authorization) per `billing_issuer` per IAL, and `false` afterwards. Refreshes write nothing (REF-9). |
| **BIL-3** | `request_id` for the billable row MUST be deterministic — `"tx:#{delegation_id}:#{billing_issuer}:#{ial}"` — so the existing unique index deduplicates. On `RecordNotUnique`, the service MUST retry with a random `request_id` and `billable: false` so the non-billable trail is kept. Session flags MUST NOT be used (the exchange runs outside the browser session). |
| **BIL-4** | New nullable columns on `sp_return_logs`, each `sensitive=false`: `access_type` (`direct` default / `delegated`), `actor_issuer`, `resource_server_identifier`, `delegated_proofing` (profile verified in the service provider session that led to this delegation). |
| **BIL-5** | The direct-flow and delegated-flow row writers MUST share one service so they cannot drift. |
| **BIL-6** | Every consumer of `sp_return_logs` MUST be reviewed for delegated rows: `UniqueMonthlyAuthCountsByIaa`, `TotalMonthlyAuthCounts`, `TotalMonthlyAuthCountsWithinIaaWindow`, `NewUniqueMonthlyUserCountsByPartner`, `Reports::DailyAuthsReport`, and `lib/reporting/identity_verification_outcomes_report.rb`. Totals MUST continue to include delegated rows; reports SHOULD add an `access_type` breakdown. |
| **BIL-7** | `token_exchange_grants` (CON-14) MUST allow reporting three outcomes per service provider, agency, API and month: requested-and-declined; consented-never-exchanged (`first_exchanged_at` null and the authorization ended); consented-and-exchanged. `proofed_in_session` MUST be recorded at consent, in the browser, where `idv_session` is available. |
| **BIL-10** | Report filters on delegated rows MUST use `COALESCE(access_type, 'direct')`: the column is nullable with a default, so pre-existing rows are NULL. The outputs of `TotalMonthlyAuthCounts`, `TotalMonthlyAuthCountsWithinIaaWindow` and `UniqueMonthlyAuthCountsByIaa` are unchanged (delegated rows included; direct + delegated for one user bills once); the access-type breakdown is a separate `results_by_access_type` array on `DailyAuthsReport`, because their specs assert exact row shapes. |
| **BIL-11** | `NewUniqueMonthlyUserCountsByPartner` MUST key a user by (user, profile, profile age, upfront) only; how the user arrived (`access_type`, `delegated_proofing`) MUST NOT be part of the key, so a user with both a direct and a delegated row under one partner in a month is one user event, and a user seen directly in one month and by delegation in a later month is not new again. The delegated facts are tallied per user alongside and reported as `partner_ial2_unique_user_events_delegated_only` and `partner_ial2_unique_user_events_delegated_proofing`. `UniqueMonthlyAuthCountsByIaa` MUST likewise report `delegated_only_unique_users` per IAL and month (users whose billable rows for the agreement that month were all delegated exchanges). All three appear as trailing columns on the invoice supplement; each is a subset of a count to its left, never an addition. |
| **BIL-12** | In the delegation outcomes report, "authorization ended" means revoked, `remember_until` passed, or a non-remembered grant whose `rails_session_id` no longer matches the identity's; approved, still-current, unexchanged grants count only in `requested`, and `proofed_in_session_not_exchanged` includes declined grants (a declined grant is also proofing with no billable agency). The report runs monthly over the report date's calendar month, is saved to S3 as `<env>/delegation-outcomes-report/<year>/<YYYY-MM>.delegation-outcomes-report.csv`, and is emailed to the new `delegation_outcomes_report_emails` config (default `[]`). |
| **BIL-9** | The delegated billing row MUST be written inside a savepoint (`transaction(requires_new: true)`) so a unique-index collision on `request_id` does not abort the exchange's enclosing transaction; the collision is then retried as the non-billable trail row (BIL-3). |
| **BIL-8** | `profiles.initiating_service_provider_issuer` MUST NOT be changed for delegation. Proofing attribution across the service provider's and the agency's partners is a reporting rule applied in the invoice supplement, using `delegated_proofing`; it is not runtime logic. |
| **BIL-13** | **The service provider is billed for its own sign-in by default; the first delegated token issued for that sign-in waives it.** The handoff writes the service provider's row exactly as for any SP (`billable: true`, `access_type: 'direct'`), and for a service provider approved for delegation also records the `identities` row it belongs to (`sp_return_logs.identity_id`). When the exchange mints the first delegated token for that connection, in the same transaction that writes the agency's billable row (BIL-1), it MUST find the most recent billable `direct` row for that `identity_id` and set `billable: false, access_type: 'delegating_sign_in'`. Within a browser session only the first handoff is billable and an exchange requires that session to be live (EXC-12), so that row is always the current sign-in's. Later exchanges from the same sign-in find nothing to waive; the waiver is never reversed; a sign-in that never leads to an exchange (the user declined every agency, or the SP never exchanged) stays billable to the service provider; a consent screen the user cancels writes no row and is billed to no one, as for every SP today. The delegation outcomes report MUST count, per service provider and month, sign-ins still billed and sign-ins waived. |
| **BIL-14** | Onboarding MUST warn when a resource server's billing issuer is not an `integrations.issuer` (no partner agreement), since its rows would be recorded and never invoiced, and the delegation outcomes report MUST show per resource server whether the billing issuer has an agreement. |

**Why BIL-9.** PostgreSQL marks the whole transaction failed after a constraint violation; without a
savepoint the exchange would roll back its token and refresh rows on the second exchange for a grant set,
which is exactly the case the deterministic `request_id` is designed to produce.

**Why BIL-1's `billing_issuer` constraints.** A row is only *billed* if its issuer resolves through
`integrations` → `integration_usages` → an in-period `iaa_order`, and `TotalMonthlyAuthCounts`
drops rows whose issuer has no `service_providers` record. `billing_issuer` MUST therefore be a
real SP issuer wired into the agency's IAA; a report warning SHOULD flag delegated rows that
aren't.

**Why BIL-2 counts per grant set, and why direct + delegated bills once.** The business model
is one billed user per agency per month. Both a direct row and a delegated row for the same
user are recorded; `UniqueMonthlyAuthCountsByIaa`'s `GROUP BY user_id` already collapses them at
report time. Nothing at runtime should try to dedup across the two paths.

**Why BIL-6 calls out the IdV outcomes report.** It counts `DISTINCT user_id WHERE ial = 2` per
issuer as "IAL2 users". Delegated rows would inflate an agency's proofing outcomes with users
proofed at the service provider. Whether to exclude `access_type = 'delegated'` there is a product decision.

### 9.3 Where and how

Extract `app/services/billing/sp_return_log_writer.rb` from
`app/controllers/concerns/billable_event_trackable.rb#create_sp_return_log`:

```ruby
module Billing
  class SpReturnLogWriter
    def self.write(user:, issuer:, ial:, request_id:, billable:, access_type: 'direct', **delegated)
      profile = user.active_profile
      SpReturnLog.create!(
        request_id:, user:, issuer:, ial:, billable:, returned_at: Time.zone.now,
        profile_id: ial > 1 ? profile&.id : nil,
        profile_verified_at: ial > 1 ? profile&.verified_at : nil,
        profile_requested_issuer: ial > 1 ? profile&.initiating_service_provider_issuer : nil,
        access_type:, **delegated,
      )
    rescue ActiveRecord::RecordNotUnique
      return nil if billable == false                       # already have the trail
      write(user:, issuer:, ial:, request_id: SecureRandom.uuid, billable: false,
            access_type:, **delegated)                        # BIL-3
    end
  end
end
```

`BillableEventTrackable` calls it for direct handoffs; the exchange form calls:

```ruby
Billing::SpReturnLogWriter.write(
  user: minted.user,
  issuer: minted.resource_server.billing_issuer,
  ial: delegated_billed_ial,                                  # IalContext-equivalent, BIL-1
  request_id: "tx:#{minted.grant.delegation_id}:#{issuer}:#{ial}",
  billable: true,
  access_type: 'delegated',
  actor_issuer: minted.service_provider.issuer,
  resource_server_identifier: minted.resource_server.identifier,
  delegated_proofing: minted.grant.proofed_in_session,
)
```

Migration adds the four columns with `comment: 'sensitive=false'`. If the partial index
`index_sp_return_logs_on_returned_at_date_issuer` changes, update
`lib/tasks/db_sp_return_logs_index.rake`, which rebuilds it by name.

`NewUniqueMonthlyUserCountsByPartner#build_queries` MUST add `delegated_proofing` and
`access_type` to SELECT and GROUP BY (and `UserVerifiedKey`) so the invoice supplement has the
data to apply whatever cross-partner proofing rule is chosen (BIL-8).

### 9.4 Delegation outcomes report

New `Reports::DelegationOutcomesReport` (`app/jobs/reports/`) over `token_exchange_grants`
joined to scopes, resource servers and SPs, monthly, with columns: service provider issuer, agency,
resource server, `requested`, `declined`, `consented_not_exchanged`, `exchanged`,
`proofed_in_session_not_exchanged`. The last column is the proofing cost with no billable
agency; the service provider's IAA covers it.

### 9.5 Amendments of 2026-10-09 (billing interview)

Where a row below conflicts with §9.2–§9.4 or *How billing works under delegated access*, this subsection governs. Decided with the product owner on 2026-10-09 (implementation plan D40–D43), adopting the reviewer's note `docs/delegated-access-billing-strategy.md` on `token-exchange2-login`.

| ID | Requirement |
|---|---|
| **BIL-4** (amend) | `sp_return_logs` gains one column only: `access_type` (`direct` default / `delegated`, `sensitive=false`) and a nullable `token_exchange_token_id` reference to the issuance record (§5.2 as amended). `actor_issuer`, `resource_server_identifier` and `delegated_proofing` are not added; the acting service provider, the resource server and `proofed_in_session` are read from the issuance record and its grant by join. |
| **BIL-6** (amend) | The `access_type` breakdown stands; any report column that names the service provider, the resource server or in-session proofing joins `token_exchange_tokens` (and `token_exchange_grants`) through `token_exchange_token_id`. |
| **BIL-8** (amend) | The proofing rule is chosen: when `proofed_in_session` is true for the grant, **every** agency that received a delegated access token in that sign-in is billed for it, proofing attribution included (`NewUniqueMonthlyUserCountsByPartner` counts the user for each such agency's partner), and the service provider's sign-in is waived (BIL-13 as replaced). `profiles.initiating_service_provider_issuer` is still not changed. |
| **BIL-11** (amend) | `delegated_proofing` in the key-exclusion and tally rules is read from the joined grant's `proofed_in_session`, not from a return-log column. |
| **BIL-13** (replace) | `sp_return_logs` rows are never updated. At the service provider's handoff, for a service provider approved for delegation, Login.gov writes a Redis entry `delegation_waiver:<SHA-256 of the service provider's access token>` holding the id of the sign-in's billable return-log row, with a TTL of **one hour** (`token_exchange_billing_waiver_cache_seconds`, default 3600). At the first exchange of a sign-in, inside the transaction that writes the agency's billable row (BIL-1), Login.gov reads the entry by the digest of the subject token and appends an `sp_return_log_billing_adjustments` row (`sp_return_log_id` the sign-in row, `delegated_sp_return_log_id` the agency row, `token_exchange_token_id`, `reason` integer enum `delegated_token_issued`, `effect` integer enum `exclude_from_billing`, timestamps). Invoice queries exclude a sign-in row that has an adjustment with `NOT EXISTS`; the waived count per service provider and month comes from the adjustments table. |
| **BIL-15** | On a cache miss, the exchange falls back to the database: it finds the most recent billable `direct` return-log row for the same `user_id` and the subject token's service provider issuer whose `returned_at` is within the sign-in that produced the subject token (the `identities` row's `last_authenticated_at` or later), and writes the adjustment from it. The exchange is never refused or delayed for billing; a miss with no row found is logged and alerted (`delegation_waiver_unresolved`). **Flagged for review by the data team:** the fallback can over-bill the service provider (row not found) or under-bill it (wrong row matched when the person signed in to the service provider more than once in the window); the review decides whether the match window needs tightening before the first invoice run. |
| **BIL-16** | Later exchanges of the same sign-in find an existing adjustment for the sign-in row and write nothing; refreshes write nothing (REF-9). A cache entry outlives nothing it needs: the subject token's sign-in must still be live at the first exchange (EXC-12), and the fallback covers an exchange made after the hour. |

**Why BIL-4/BIL-13.** A return log is an append-only record of a handoff; it is not the place for facts about a later exchange, and mutating it would make the invoice depend on the order in which jobs ran. The issuance record already knows the service provider, the resource server and the grant, so the join costs one foreign key and keeps every report's history reproducible. The one-hour TTL keeps the common case (exchange seconds after the handoff) in Redis while the database fallback keeps correctness for the uncommon one.

---

## 10. Configuration and feature flags

New `IdentityConfig` keys (`lib/identity_config.rb`, defaults in `config/application.yml.default`):

| Key | Type | Default | Purpose |
|---|---|---|---|
| `token_exchange_enabled` | boolean | `false` | Master switch for exchange, introspection, revocation and refresh |
| `token_exchange_access_token_ttl_seconds` | integer | `900` | REF-5 |
| `token_exchange_refresh_token_ttl_seconds` | integer | `43_200` | REF-5 |
| `token_exchange_introspection_cache_seconds` | integer | `60` | INT-8; published in the integration guide |
| `token_exchange_per_sp_max_attempts` / `_attempt_window_in_minutes` | integer | e.g. `600` / `1` | EXC-8 |
| `introspection_per_resource_server_max_attempts` / `_attempt_window_in_minutes` | integer | e.g. `6_000` / `1` | INT-7 |
| `refresh_per_sp_max_attempts` / `_attempt_window_in_minutes` | integer | e.g. `600` / `1` | REF-2 rate limit |

Everything else — service providers, resource servers, scopes, keys — lives in SP configuration (ONB-5),
not in application config.

**Amended 2026-10-09 (D27, D37).** `token_exchange_introspection_cache_seconds`, `token_exchange_per_sp_*`,
`introspection_per_resource_server_*` and `refresh_per_sp_*` are not introduced (INT-8, EXC-8, INT-7 and
REF-13 as amended). In their place, `token_exchange_alert_exchanges_per_minute`,
`token_exchange_alert_refreshes_per_minute`, `token_exchange_alert_introspections_per_minute` and
`token_exchange_alert_error_rate_percent` are integer thresholds read by the monitoring that raises an
alert when one caller's volume or error rate exceeds them over a one-minute window; they refuse nothing.
Per-resource-server `max_access_token_seconds` and `max_family_seconds` are SP-configuration fields
(ONB-5), not application config.

**Amended 2026-10-09 (D41, D47, D49).** `token_exchange_billing_waiver_cache_seconds` (integer, default `3600`, BIL-13 as replaced) is added by the billing feature. No key is added for DPoP: binding follows the client type and the per-resource-server `dpop_required` field is removed (EXC-9 as amended). `document_images_sharing_enabled` and `document_images_sharing_service_providers` (inherited from `sbx-taigrr`) keep their `false` and `[]` defaults and are set only in the sandbox's `application.yml` (DOC-1).

**Amended 2026-10-09 (D56).** `site_key_enabled` (boolean, default `false`) arrives with the ported per-site keys feature (§17) and is independent of `token_exchange_enabled`; the per-service-provider `site_key_allowed` column is SP configuration set only from `service_providers.yml`.

---

## 11. Security requirements summary

| Threat | Control | Requirement |
|---|---|---|
| Service provider token stolen via XSS and exchanged | Exchange and refresh grants require the service provider's private key; PKCE not accepted for them | EXC-2 |
| Stolen delegated token used at another API | One token per API; introspection checks caller = `aud` | EXC-4, INT-2 |
| Stolen delegated token used at the right API | Key binding (DPoP): the token is useless without a proof from the service provider's key; 15-minute life and instant revocation bound the exposure of an unbound token at an API that did not require binding. | EXC-9, INT-4, REF-3, §6.3 item 11 |
| Stolen refresh token | Rotation + reuse detection revokes family; hashed at rest | REF-4, REF-7 |
| Service provider widens its own reach | Targets defined only by Login.gov; grants per scope | ONB-3, CON-2, CON-11 |
| Target API accepts service provider's `id_token` | `aud` never lists targets; guide forbids it | CON-16, §6.3 |
| Exchange revives revoked consent or hijacks direct session | Separate token table; target identity row untouched | EXC-5 |
| Assertion replay against introspection | `jti` cache, required short `exp` | INT-6 |
| Probing tokens via introspection | Authenticate caller first; bare `active: false` | INT-1, INT-3 |
| Content injection on consent screen | DB-only content, escaped | CON-8 |
| Agency loses fraud visibility | Attempts events delivered at consent with `delegation_id` | §8 |
| High-volume agency callers trip per-IP limits or get allowlisted into no limits | Per-client rate limits | EXC-8, INT-7 |

**Amended 2026-10-09 (D37).** The last row's control is replaced: no per-client rate limit exists. The
control is per-client volume and error-rate alerting (EXC-8, INT-7, REF-13 as amended), with runaway-caller
protection at the infrastructure layer.

---

## 12. Testing requirements

- **Request specs** for exchange, introspection, refresh and revocation covering every error
  branch in EXC-3, INT-2, REF-2–REF-4, with the RFC error codes asserted.
- **Feature spec** for the consent screen: subset approval, none approved, remember checked vs
  unchecked, returning user with remembered grants (screen skipped), service provider adds a scope
  (screen shown pre-filled), content version bump (screen shown), declined value re-requested
  (screen shown again, value unchecked, even with approvals remembered), declined value never
  appears in `verified_attributes` or the token `scope`.
- **Account page spec**: list, time remaining, revoke cascades to tokens and emits the event.
- **Attempts specs**: events reach approved agencies only; `subject.session_id` unchanged;
  `delegation_id` present; no `AgencyIdentity` for declined agencies; `remembered: true` path.
- **Billing specs**: one billable row per grant set; refresh writes none; direct + delegated in
  one month bills one user in `UniqueMonthlyAuthCountsByIaa`; retry-on-collision keeps the
  non-billable row.
- **Rate-limit specs** keyed on service provider and resource server.
- **i18n**: `spec/i18n_spec.rb` already checks interpolation-argument consistency across
  locales; every new key with `%{...}` MUST be exercised with all arguments in a controller spec
  (a missing argument renders the literal placeholder and is not caught otherwise).
- **Schema**: `spec/db/schema_spec.rb` enforces `sensitive=` comments.

New code MUST satisfy these suite conventions (learned while implementing):

- `spec/i18n_spec.rb` fails on any key whose `es`/`fr`/`zh` value equals the English, so every new
  user-facing key needs real translations in all four locale files (flat dotted keys, sorted); keys
  ending in `_html` must contain a literal HTML tag in at least one locale, so keys that only
  interpolate plain text must not be named `_html`.
- `make lint_analytics_events` requires every keyword of every `AnalyticsEvents` method to have a
  `@param` docstring, and `lint_analytics_events_sorted` requires the methods to be alphabetical;
  `FakeAnalytics` raises in specs when an undocumented keyword is passed, so adding a field to an
  existing event (e.g. `delegation_scopes` on `openid_connect_request_authorization`) means updating
  the docstring and any spec that compares the whole hash.
- Bullet runs in feature specs and fails both on N+1 loads and on eager loads it judges unused;
  loading small related sets one table at a time and joining in memory avoids both.
- The reference agency viewers poll the Attempts API without acknowledging (ATT-18), so delivered
  events persist for the retention window and pile up across scenarios; the end-to-end harness empties
  the IdP's Attempts store (`attempts-api-events:*`) before each scenario so the agency-viewer
  assertions see only that scenario's own events.
- Rack::Test drives the consent flow without JavaScript: after the completion screen the handoff is
  a form (`forms.buttons.submit.default`), and a first connection to an SP shows the authorization
  confirmation page (`user_authorization_confirmation.sign_in`) before the code is issued. Feature
  specs must click through both.
- `make normalize_yaml` rewrites every YAML file in the repository including `config/locales/*.yml`, not only
  the OpenAPI docs; do not run it as part of Attempts schema work. `docs/attempts-api/compiled-api.yml` is a
  local build artifact (`npm run build:openapi`) that `tracker_events_spec.rb` needs and that is not committed.
- `identity-idp`'s rubocop excludes `db/primary_migrate/*` and `db/schema.rb`; a custom cop
  (`IdentityIdp/ErrorsAddLinter`) requires a symbol key on `errors.add`, and another forbids
  comparing `current_path` directly in Capybara specs.
- Local test runs need built assets (`npm run build:css` for the mailer layout, `npm run build:js`
  for the application layout spec) and a Chrome driver for `:js` specs.

---

## 13. Rollout

1. Ship the data model (§3) and the account page (§4.7) behind `token_exchange_enabled: false`.
   Land the reference apps and harness (§14) against a local IdP at the same time; the harness
   is the acceptance test for every later step.
2. Enable consent and exchange for one service provider and one resource server in the sandbox
   (`idp.int.identitysandbox.gov`).
3. Enable introspection and Attempts delivery for that agency; verify the agency can join
   `delegation_id` across both.
4. Turn on billing rows; reconcile one month of `DelegationOutcomesReport` against the invoice
   supplement.
5. Confirm with each agency that its API verifies the DPoP proof on every request for tokens issued to a public-client service provider (RS-DPOP-1); there is no per-API `dpop_required` setting (EXC-9 as amended, 2026-10-09).

---

## 14. Reference implementations and end-to-end test harness

### 14.1 Why this is a requirement, not a nice-to-have

Everything in §3–§9 puts new obligations on partners: service providers must exchange server-side with a
signed assertion and rotate refresh tokens; agency APIs must introspect, enforce
scope, and join Attempts events on `delegation_id`. None of that exists in any
partner codebase today. Without working examples, each partner will interpret the standards
differently, and Login.gov will debug the same integration mistakes agency by agency. A
reference service provider and a reference resource server, runnable together against a local or sandbox
IdP, are how the design gets validated with the first partner agencies and how later agencies
onboard without a support engagement.

Login.gov already maintains a sample relying party, `identity-oidc-sinatra` (Sinatra, ~560
lines in `app.rb`), with an Attempts API viewer. This section extends it into the **service provider**
reference and adds a small **resource server** reference alongside it.

### 14.2 Requirements

| ID | Requirement |
|---|---|
| **REF-IMPL-1** | `identity-oidc-sinatra` MUST be extended to act as a reference **service provider**: request `token_exchange:*` scopes, display what the user approved, perform the exchange server-side with `private_key_jwt`, call a resource server with the delegated token, refresh on a timer with rotation, and revoke on demand. |
| **REF-IMPL-2** | A reference **resource server** MUST be provided — either a second mode of the Sinatra app selected by environment variable, or a sibling app in the same repository — that accepts delegated tokens, introspects them with its own `private_key_jwt` assertion, enforces `scope` per route, and shows every decision it made. |
| **REF-IMPL-3** | The resource server reference MUST include an Attempts API viewer, in the **agency** role, that polls with the agency's credentials and joins events to API calls on `delegation_id`. |
| **REF-IMPL-4** | Both roles MUST run against a local IdP with a single command, using `config/service_providers.localdev.yml` entries shipped in `identity-idp`, and against the sandbox (`idp.int.identitysandbox.gov`) by changing environment variables only. |
| **REF-IMPL-5** | An automated end-to-end test MUST drive the full flow — sign in, consent (subset, remember on/off), exchange, API call, introspection, refresh, reuse detection, revocation, Attempts delivery — and MUST run in CI against a local IdP. |
| **REF-IMPL-6** | The repository MUST include a partner-facing guide: a sequence diagram, the exact requests and responses, the assertion payloads, error handling, and a checklist for each role derived from §5.3, §6.3 and §7. |
| **REF-IMPL-7** | Reference code MUST be written so that partners can copy it: one function per protocol step, standards cited in comments, no framework-specific cleverness. |
| **REF-IMPL-8** | The reference service provider MUST keep the sign-in access token, refresh tokens and delegated tokens **server-side**; the cookie MAY hold only an opaque store key. A multi-process deployment needs a shared backend, and the README MUST say so. |
| **REF-IMPL-9** | The end-to-end harness MUST be skipped automatically when no IdP is configured (`E2E_IDP_URL` unset) so unit CI passes without a stack; scenarios that need a wait or a server-side token MUST be gated behind explicit environment variables and marked pending otherwise. |
| **REF-IMPL-10** | Every Attempts API viewer in the reference apps MUST decode **unsigned** events as JSON as well as signed ones, and MUST poll once per page load. |

**Why REF-IMPL-8.** The sample app's cookie session cannot hold several tokens safely, and putting
delegated tokens in a browser cookie would recreate the exposure the server-side exchange exists to
prevent.

**Why REF-IMPL-10.** The upstream viewer only decoded signed events and posted twice, discarding the
first response's `sets`; with `attempts_api_signing_enabled: false` (the local default) nothing rendered.
The reference viewers also poll **without** acknowledging (no `ack`): an agency operator refreshing the
page should keep seeing the last hour of activity, so the demo deliberately leaves events in the store.
A production agency does the opposite and acknowledges to advance the pointer (ATT-18); the end-to-end
harness, in turn, resets the store between scenarios rather than acknowledging.

**Amended 2026-10-09 (D57, D58).** Where a row above conflicts with this paragraph, this paragraph governs. The reference **service provider** (`identity-sts-sinatra`, rewritten `main` of `https://github.com/GSA-TTS/identity-sts-sinatra`) is a standards-based browser public client: it signs in with PKCE (`pkce: true` on its SP record, no `private_key_jwt`), generates its DPoP key non-extractable with WebCrypto and keeps it in the browser as an IndexedDB `CryptoKey` (a new key per sign-in), sends `dpop_jkt` on the authorization request (EXC-19), and makes the authorization-code exchange, the token exchange, refresh, revocation and the agency API calls from the browser, each with a DPoP proof (`htm`, `htu`, `iat`, `jti`, `ath`), including the `DPoP-Nonce` retry loop of RFC 9449 §8 (on `use_dpop_nonce` or a `WWW-Authenticate: DPoP error="use_dpop_nonce"` challenge the client retries once with the returned nonce) even though Login.gov does not issue nonces (E28, E57). Its server is static hosting plus a non-secret JSON configuration (issuer, `client_id`, redirect URI, agency API origins and resource identifiers, delegation scopes); it holds no private key, no shared secret and no token. REF-IMPL-1 reads accordingly ("perform the exchange from the browser with a DPoP proof" in place of "server-side with `private_key_jwt`"); REF-IMPL-8 is withdrawn (there is no server session: tokens live in page memory for the sign-in and the DPoP key never leaves the browser, so a stolen token is unusable without it, §5.5); REF-IMPL-9's "server-side token" clause becomes "a token read from the browser". Attempts API code is removed from `identity-sts-sinatra` and from `identity-saml-sinatra`, neither of which had it upstream before this project; REF-IMPL-3 and REF-IMPL-10 apply to `identity-oidc-sinatra`, which keeps the viewer it already had. Rejected: a confidential-client reference (contradicts §5.5), and a server that signs DPoP proofs for the browser (a proof from a key the browser does not hold binds nothing to the browser).

### 14.3 Service provider reference — changes to `identity-oidc-sinatra`

Baseline: `907fc7f`. File references are to `app.rb` unless noted.

**Configuration** (`config.rb`). New environment variables, with defaults for local use:

| Variable | Purpose |
|---|---|
| `ROLE` | `service_provider` (default) or `resource_server` (§14.4) |
| `DELEGATION_SCOPES` | Space-separated `token_exchange:*` values to offer, e.g. `token_exchange:[agency-api-scope-a] token_exchange:[agency-api-scope-b]` |
| `RESOURCE_SERVER_URL` | Base URL of the reference resource server to call after exchange |
| `RESOURCE_IDENTIFIER` | The `resource` value for the exchange, e.g. `https://[agency-api]` |
| `REFRESH_INTERVAL_SECONDS` | How often the demo refresh loop runs (default 600) |

**Authorize request** (`#scope_options` :88, `#default_scopes_by_ial` :112,
`views/auth_options.erb`, `#authorization_url` :365). Add a "Delegated access" group of checkboxes
populated from `DELEGATION_SCOPES`, only enabled when IAL2 is selected (CON-4). Pass them through
unchanged in `scope`.

**Token response** (`#token` :476, `/auth/result` :268). Read the `scope` field of the token
response and show the user two lists: *delegation you approved* and *delegation you declined*
(CON-15). Store the access token **server-side** in the session store, not in a cookie; today the
app stores only the `userinfo` result (:299), which is correct — keep the token out of the browser.

**Exchange** — new `#exchange(resource:)`:

```ruby
# RFC 8693 token exchange, RFC 8707 resource indicator, RFC 7523 client authentication.
def exchange(resource:)
  body = {
    grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
    subject_token: session[:access_token],
    subject_token_type: 'urn:ietf:params:oauth:token-type:access_token',
    resource: resource,
    client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
    client_assertion: client_assertion_jwt(audience: openid_configuration['token_endpoint']),  # same aud as today
  }
  json(Faraday.post(openid_configuration['token_endpoint'], body))   # RFC 8693 §2.1: the token endpoint
end
```

Reuse `#client_assertion_jwt` (:502), parameterized by audience; it already sends `jti` and
`exp`.

**Calling the resource server** — new `GET /delegated/call`:

```ruby
get '/delegated/call' do
  family = session[:delegations][params[:resource]]
  headers = { 'Authorization' => "Bearer #{family[:access_token]}" }   # RFC 6750 §2.1
  @api_response = json(Faraday.get(resource_url, nil, headers))
  erb :delegated
end
```

**Refresh** — new `#refresh(family)` implementing RFC 6749 §6 with rotation (REF-4): persist the
new `refresh_token` from the response *before* using the new access token; on `invalid_grant`,
clear the family and show "consent required again". A background thread or a "Refresh now"
button drives it; the view shows the token's `exp` counting down.

**Revoke** — new `POST /delegated/revoke` calling `/api/openid_connect/revoke` (RFC 7009) for the
family.

**Views** — new `views/delegated.erb`: per resource, the approved scopes, the current access
token's expiry, refresh count, the last API response (including the introspection decision the
resource server echoes back, §14.4), and buttons for *Call API*, *Refresh now*, *Replay old
refresh token* (to demonstrate reuse detection), and *Revoke*.

**Existing bug to fix while here:** `#attempts_events` (:145–182) calls `connection.post` twice
(:159 and :167); the second call discards the first response's `sets`.

*As built:* the sample app keeps only the `userinfo` result in the cookie session, and the cookie
cannot safely hold the sign-in access token, refresh tokens and delegated tokens either. The
reference service provider stores them in an in-process `TokenStore` keyed by a random id that is
the only thing placed in the cookie; a multi-process deployment needs a shared backend (documented
in the repo). Exchange requests always send `requested_token_type` (default `…:access_token`) and
never `scope` or `code_verifier`; refresh sends neither `scope` nor `resource`; revoke sends
`token_type_hint=refresh_token`. On `invalid_grant` the family is cleared and the UI says consent is
required again, so the "replay a rotated refresh token" demo shows the token gone rather than a
live 401 from the API.

**Amended 2026-10-09 (D57).** The code in this subsection describes the withdrawn server-side reference and is kept for the protocol steps it names. In the browser public client the same steps are: `exchange(resource)` posts `grant_type`, `subject_token` (the access token held in page memory), `subject_token_type`, `resource` and `requested_token_type` with `client_id` and a `DPoP` header whose `ath` is over the subject token, no `client_assertion`; the API call sends `Authorization: DPoP <token>` and a proof with `ath` over it; `refresh(family)` sends the rotated refresh token with a proof from the same key; `revoke(family)` posts to `/api/openid_connect/revoke` with a proof. On `use_dpop_nonce` from any of those servers the client retries once with the `DPoP-Nonce` it was given. The `TokenStore` and cookie-keyed server session described under *As built* no longer exist.

### 14.4 Resource server reference

Recommended: a second Sinatra app in the same repository, `resource_server/app.rb`, sharing
`config.rb` helpers, started with `ROLE=resource_server`. Keeping both roles in one repo lets one
`docker compose up` bring up the whole demo.

> Repository layout as built: the roles are split across separate repositories (one service
> provider, one OIDC resource server, one SAML resource server) rather than one `ROLE`-switched app.
> Appendix D records which repository implements which section. The requirements in this section
> are unchanged; only the packaging differs.

**Configuration:** `RESOURCE_IDENTIFIER` (its own identifier, e.g. `https://[agency-api]`),
`RS_PRIVATE_KEY` (for introspection assertions), `IDP_DOMAIN`, `INTROSPECTION_CACHE_SECONDS`
(default from discovery, INT-8), `ATTEMPTS_SHARED_SECRET` and `ATTEMPTS_PRIVATE_KEY` for the
agency-role viewer.

**Routes.** Two example endpoints with different scope requirements, so scope enforcement is
visible:

```ruby
get '/records' do       # requires token_exchange:[agency-api-scope-a]
  authorize!('[agency-api-scope-a]')
  json_response(records_for(@introspection['sub']))
end

post '/records' do      # requires token_exchange:[agency-api-scope-b]  (read_write)
  authorize!('[agency-api-scope-b]')
  ...
end
```

**`#authorize!(required_scope)`** — the code partners will copy:

```ruby
def authorize!(required_scope)
  token = bearer_token(request)                                     # RFC 6750 §2.1
  halt 401, www_authenticate('Bearer') unless token

  @introspection = cached_introspection(token) || introspect(token)  # RFC 7662; cache ≤ INT-8 window
  halt 401, www_authenticate('Bearer', error: 'invalid_token') unless @introspection['active']
  halt 403, error('insufficient_scope') unless @introspection['scope'].split.include?(required_scope)

  log_decision(@introspection)   # sub, act.sub, delegation_id, scope, decision — shown in the UI
end

def introspect(token)
  body = {
    token: token,
    client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
    client_assertion: rs_client_assertion(audience: openid_configuration['introspection_endpoint']),  # RFC 7523 §3; exp ≤ 5 min, unique jti
  }
  json(Faraday.post(openid_configuration['introspection_endpoint'], body))
end
```

The API response SHOULD echo the introspection result so the service provider UI can display *why*
a call was allowed or refused. This is a demo affordance; a production API would not do it.

| ID | Requirement |
|---|---|
| **REF-IMPL-12** | The reference service provider MUST treat a SAML assertion as single-use: it presents a given assertion to the agency API at most once and refreshes (obtaining a fresh assertion) before any further call, unless the agency has declared that it accepts reuse (SAML-10). The first live run showed the reference SAML resource server correctly refusing the second presentation of one assertion ("assertion has already been presented"). |
| **REF-IMPL-11** | Anything a reference resource server echoes back to the service provider from an introspection response MUST be filtered to the token members (`active`, `aud`, `scope`, `act`, `client_id`, `acr`, `iat`, `exp`, `token_type`, `delegation_id`, `attributes`). Identity claims (INT-10) MUST be consumed by the API exactly as userinfo claims are, with the same SSN redaction, and MUST never be echoed unredacted to the service provider. |

**Why REF-IMPL-11.** Once introspection carries the agency's identity claims, echoing the raw response
would hand the service provider attributes (including SSN) the user never approved for it — the very
leak that keeping delegated tokens out of `userinfo` prevents.

**Fail closed.** If introspection errors or times out, respond 503 and do not serve the request
(§6.3 item 3).

**Agency-role Attempts viewer.** Reuse `views/attempts.erb` / `views/event.erb` and
`#attempts_events`, configured with the *agency's* Attempts credentials. Add a "Delegated
sessions" tab that groups events by `delegation_id` and lists the API calls (from
`log_decision`) with the same `delegation_id` beneath them — this is the join agencies will
implement (§8.5). Extend `ALLOWED_PLAINTEXT_KEYS` (:28–46) with `actor_issuer`, `scopes`,
`resources`, `remembered`, `ial`, `aal`, `delegation_id`, `reason`.

### 14.5 Local IdP fixtures (`identity-idp`)

Add to `config/service_providers.localdev.yml`, under `development`:

- a service provider `urn:gov:gsa:openidconnect:sp:[agency]:[service-provider-name]` with
  `token_exchange_enabled_sp: true`, IAL2, `redirect_uris` for `http://localhost:9292`, `certs`
  pointing at the sample RP's `config/demo_sp.crt`, and the ONB-4 service provider content.
  *As built:* every local actor carries a realistic but fictitious government name so the consent
  screen reads naturally — the service provider is **MyBenefits Assistant**, run by the **Office of
  Benefits Coordination** (agency 100); the OIDC agency is the **Department of Housing Support**
  (agency 101: "See the status of your housing assistance case", "Update your housing
  application"); the SAML agency is the **National Retirement Administration** (agency 102: "See your
  retirement benefit statement", "Update your mailing address on file"). The agencies are added to
  `config/agencies.localdev.yml`; issuers, identifiers and scope values are unchanged;
- an agency SP `urn:gov:gsa:openidconnect:sp:[target-agency]:[service-provider-name]` with
  `token_exchange_target: true`, a different `agency_id` from the service provider (so the demo shows a
  *different* `sub` at the target, and a second fixture with the *same* `agency_id` to show
  `act` doing the work — INT-5), one resource server `https://[agency-api]` with two scopes
  (`[agency-api-scope-a]` read, `[agency-api-scope-b]` read_write), and Attempts API
  enrollment in `allowed_attempts_providers` for the localdev environment.

Add a `bin/` or `make` target in `identity-oidc-sinatra` that generates the resource server key
pair and prints the PEM to paste into the fixture.

**Amended 2026-10-09 (D47, D51).** The fixture is `config/delegated_access.localdev.yml`, loaded by `rake delegated_access:seed` (§3.4 as built), and it is the **single contract** between the identity-idp seed task and the `identity-sts-sinatra` end-to-end harness (§14.6): one public-client service provider (`pkce: true`, DPoP, MyBenefits Assistant / Office of Benefits Coordination), two agency applications with one `oauth` API (Department of Housing Support, Housing Assistance Records) and one `saml2` API (National Retirement Administration, Retirement Benefits Portal), and the Department of State's direct-service-provider record on the document-images allow-list (DOC-1). The harness reads issuers, identifiers, scope values and hostnames from this file and from nowhere else. The sandbox seed task (`delegated_access:seed_sandbox`) reads the same file with hostnames substituted from the environment. The `dpop_required` key is removed from the file (EXC-9 as amended); the `service_providers.localdev.yml` additions described above are superseded by it.

### 14.6 End-to-end test harness

- **Compose file** (`docker-compose.e2e.yml` in `identity-oidc-sinatra`): `idp` (from
  `identity-idp`'s existing Dockerfile), `service_provider` (`ROLE=service_provider`), `resource_server`
  (`ROLE=resource_server`), Postgres, Redis.
- **Test runner:** Playwright (the repo already has `package.json` and `spec/js`) driving the
  browser through sign-in and consent, with Ruby request specs for the server-to-server steps.
  Scenarios, each asserting the RFC error code or response field named in the requirement:
  1. Approve both scopes, remember off → exchange each → call both endpoints → 200s.
  2. Approve A only → call A 200, call B 403 `insufficient_scope`; exchange for B `invalid_target`.
  3. Approve none → token `scope` has no `token_exchange:*`; exchange `invalid_target` (no consent for
     that target; see Appendix E, E26).
  4. Remember on → second authorization skips consent; `delegated-access-consented` arrives
     with `remembered: true`.
  5. Service provider adds scope B on second authorization → consent shown pre-filled with A.
  5a. Approve A, decline B, remember on → second authorization requesting A and B → consent
      shown, A checked, B unchecked; approve B → exchange for B succeeds.
  6. Refresh → new token works; old access token `active: false` after expiry.
  7. Replay a rotated refresh token → `invalid_grant`; family revoked; API call 401;
     `delegated-access-revoked` with `reason: refresh_token_reuse`.
  8. Revoke from *Account → Delegated access* → API call 401 within the cache window;
     event delivered.
  9. Wrong caller: resource server B introspects a token for A → `active: false`.
  11. Attempts: agency viewer shows sign-in, MFA, consent, token-issued events under one
      `delegation_id` (the agency's join key; `subject.session_id` is the service provider's and the
      viewer redacts it, per ATT-3); the declined agency's viewer shows nothing under that
      `delegation_id`.
  12. Billing (request spec in `identity-idp`): one `sp_return_logs` row per exchange with
      `access_type: delegated`; refresh adds none; direct + delegated same month → one user in
      `UniqueMonthlyAuthCountsByIaa`.
- **CI:** run the harness in `identity-oidc-sinatra`'s CI (`dockerfiles/ci.Dockerfile`) against a
  pinned `identity-idp` image, and in `identity-idp`'s CI for scenario 12.

*Learned in the first live run (2026-09-29):* none of these were product bugs; they are steps a real user
takes that the harness must take too. The browser harness must drive every IdP page a
real user can meet — the rules-of-use acceptance on a user's first sign-in, the "add a second
authentication method" reminder for single-MFA users (button "Continue to <SP>"), the first-visit
authorization confirmation, and the RP-initiated logout confirmation — and must find USWDS checkboxes with
`visible: :all` and toggle them through their labels. The reference resource server answers `201 Created`
to a write, so scenario expectations use 201, not 200. WebMock must be disabled for the live run. The
service provider's IAL gating must react to the `change` event as well as `input`, since automation fires
only `change` on a `<select>`. Running servers must be restarted after pulling new commits (Sinatra does
not reload), and the IdP must be re-seeded after a fixture certificate file is added, because the seeder
copies PEM contents into the row.

*As built:* the harness lives in the service provider repository (`spec/e2e/`, Capybara + Selenium)
and is skipped unless `E2E_IDP_URL` is set, so unit CI stays green without a stack. The compose file
uses host networking so every URL matches the local contract. Scenario 6 (old access token inactive
after expiry) needs a 15-minute wait and is gated behind `E2E_WAIT_FOR_EXPIRY=true`. Scenario 9
(wrong caller introspects) needs the delegated tokens, which are server-side by design, so the spec
reads them from `E2E_RECORDS_TOKEN` / `E2E_BENEFITS_TOKEN` when provided. Scenario 3 asserts
`invalid_target` for "nothing approved" (Appendix E, E26).

Two run details matter locally, both learned in a live run. First, the harness MUST sign in as an
identity-verified (IAL2) development user: in the primed data that is `test2@test.com`, not the
unverified `test1@test.com` the helper defaults to, or every scenario stops at `/verify/welcome`
(`E2E_USER_EMAIL` overrides the default). Second, the IdP SHOULD run with `LAUNCHY_DRY_RUN=true`,
which stops launchy from auto-opening development emails in a browser during the run while
letter_opener still writes them to `tmp/letter_opener/`. Each scenario also begins by emptying the
IdP's Attempts store (`attempts-api-events:*`) so the agency viewer reflects only that scenario, since
the reference viewers poll without acknowledging (ATT-18).

**Amended 2026-10-09 (D57).** With the service provider a browser public client there are no "server-to-server steps" on its side: the harness drives the page through sign-in, consent, exchange, API call, refresh and revocation, and reads tokens and the DPoP thumbprint from the page rather than from `E2E_RECORDS_TOKEN` / `E2E_BENEFITS_TOKEN`. Scenario 9 (wrong caller introspects) runs as a request spec against the agency reference APIs with those values. The compose file serves the service provider as static files.

### 14.7 Partner guide (`docs/delegated-access.md` in `identity-oidc-sinatra`)

1. Sequence diagram of §2.2 with the file and function that implements each arrow in the
   reference apps.
2. "Service provider checklist" and "Resource server checklist", one line per obligation in §5.3, §6.3,
   §7, each linking to the reference function and the RFC section.
3. Every request and response from the harness, captured verbatim with placeholders, including
   every error case.
4. Sandbox onboarding steps: what to send Login.gov (identifiers, certs, scope content) and what
   to expect back.

---

## 15. Item 7 — SAML assertions as an issued token type

**Depends on:** §5 (token exchange at the token endpoint), §6 (introspection) and §7 (refresh
families) as specified. This item changes only *what is minted*; the request, client
authentication, `resource` parameter, grant checks, refresh, revocation, billing and Attempts
events are unchanged. It can be built and shipped after the OAuth path is live.

### Objective

- **Outcome.** A service provider can ask the exchange for a **SAML 2.0 assertion** instead of an
  OAuth access token, for agency APIs that consume SAML. The assertion is scoped to one resource
  server and carries only the capabilities the user approved for it, so the same consent controls
  the same access.
- **Why.** Many agency APIs already trust Login.gov's SAML signing certificate and validate SAML
  assertions; some cannot adopt OAuth introspection quickly. RFC 8693 was written for exactly this
  case — one security token service issuing whichever token format the target needs — and
  Login.gov already has the code that builds, signs and encrypts SAML assertions.
- **Success criteria.**
  1. `requested_token_type=urn:ietf:params:oauth:token-type:saml2` returns a signed (and, when
     the resource server has a certificate, encrypted) SAML 2.0 assertion whose `Audience` is the
     one requested resource server.
  2. The assertion's attribute statement lists exactly the approved capability values for that
     resource, the `delegation_id`, and the acting service provider (`actor`, the SAML counterpart
     of the OAuth `act` claim); nothing about other resources.
  3. Every issued assertion is recorded in `token_exchange_tokens`, so revocation at refresh, the
     account page and billing work for SAML exactly as for OAuth tokens.
  4. The assertion is built with the existing `saml_idp` gem, `AttributeAsserter` and
     `SamlEndpoint` code paths; no second assertion builder is introduced.
  5. The reference resource server validates the assertion with `ruby-saml` and enforces scope
     from the attribute statement, with no call back to Login.gov.

### 15.1 What RFC 8693 already provides

- `requested_token_type` (§2.1) is an optional request parameter. §3 defines the identifier
  `urn:ietf:params:oauth:token-type:saml2` (and `saml1`, which this item does not support).
- The issued token is returned in `access_token` regardless of format (§2.2.1). `issued_token_type`
  is REQUIRED and names the format. `token_type` MUST be `N_A` when the issued token is not an
  OAuth bearer token usable at Login.gov — which is the case for a SAML assertion.
- `refresh_token` MAY be returned. The refresh family (§7) simply remembers the requested type.

RFC 7522 (SAML assertions as OAuth *grants*) is the opposite direction — a client presenting an
assertion *to* an authorization server — and does not apply here.

### 15.2 Existing code this item reuses

| Component | What it does today | How this item uses it |
|---|---|---|
| `saml_idp` gem (Login.gov's maintained copy, `18F/saml_idp` tag `v0.25.3-18f`, a dependency of `identity-idp` today) — `SamlIdp::AssertionBuilder` (`#signed`, `#encrypt(sign: true)`), used by `SamlIdp::SamlResponse` | Builds, signs and optionally encrypts the assertion for `SamlIdpController` | Called directly with the same 14 positional arguments `SamlResponse#assertion_builder` passes today; `audience_uri`, `saml_acs_url` and `saml_request_id` come from the exchange instead of an AuthnRequest. The `<samlp:Response>` wrapper (`ResponseBuilder`) is not used, because RFC 8693's `saml2` token is the bare assertion. |
| `SamlIdpAuthConcern#saml_response_options` and `#encryption_opts`, `#saml_response_signature_options` | Assembles `name_id_format`, `authn_context_classref`, `reference_id`, `encryption`, `signature`, `authn_instant` | Extracted into a small module usable outside a controller, then called with the agency SP and the service provider's identity |
| `AttributeAsserter` | Builds `user.asserted_attributes` from the SP's attribute bundle, IAL, AAL | Called with `service_provider: <agency SP>`; the three delegation attributes are appended to its result |
| `SamlEndpoint` | Year-suffixed signing keys and certificates; metadata at `/api/saml/metadata` | Signs the assertion; resource servers already trust this metadata |
| `ServiceProvider#ssl_certs`, `#encrypt_responses?`, `block_encryption` | Encrypts responses to the RP's certificate | The resource server's `certs` (already collected at onboarding, §3) are used the same way |
| `config/initializers/saml_idp.rb` `name_id.formats[:persistent]` | Pairwise NameID from `asserted_attributes[:uuid]` | Unchanged; gives the same per-agency identifier introspection returns as `sub` |
| `saml_idp` `AssertionBuilder#fresh` | Emits, in order: `Issuer`, `Signature`, `Subject` (`NameID` + bearer `SubjectConfirmation` with `SubjectConfirmationData InResponseTo/NotOnOrAfter/Recipient`), `Conditions` (`NotBefore/NotOnOrAfter` + `AudienceRestriction`), `AttributeStatement`, `AuthnStatement` | One-line fix in the `saml_idp` gem (verified against the pinned tag): omit `InResponseTo` when `saml_request_id` is nil — today the builder would emit an empty, schema-invalid `InResponseTo=""`. Everything the delegated assertion needs, including the `actor` attribute, goes through the existing `asserted_attributes` path; no other builder change. |

### 15.3 Requirements

| ID | Requirement |
|---|---|
| **SAML-1** | The exchange (EXC-1) MUST accept `requested_token_type`. Absent, or `urn:ietf:params:oauth:token-type:access_token`, behaves as §5. `urn:ietf:params:oauth:token-type:saml2` mints a SAML 2.0 assertion. Any other value MUST fail with `invalid_request`. |
| **SAML-2** | The response MUST carry the base64url-encoded **assertion** (not a `<samlp:Response>` wrapper — RFC 8693 §3 defines `saml2` as "a base64url-encoded SAML 2.0 assertion") in `access_token`, `issued_token_type: urn:ietf:params:oauth:token-type:saml2`, `token_type: N_A`, `expires_in`, `scope`, and `refresh_token` per §7. |
| **SAML-3** | Login.gov MUST issue a SAML assertion for a resource server only if its `token_format` is `saml2` (SAML-9). Otherwise `requested_token_type=…:saml2` MUST fail with `invalid_target`. |
| **SAML-4** | The assertion MUST use the **same lifetime as the browser SAML flow**: `Conditions/@NotBefore` = issuance − 5 s and `Conditions/@NotOnOrAfter` = issuance + 1 hour (the `saml_idp` default `expiry` of 3600 s; `identity-idp` passes no override today). `SubjectConfirmationData/@NotOnOrAfter` MUST be issuance + **5 minutes** (the gem fixes it at 3 minutes for browser POSTs; 15.4). Validators that enforce the subject-confirmation window — most do — will therefore accept a given assertion for five minutes; the service provider refreshes (SAML-9) to get a fresh one. The assertion MUST have: `Issuer` = Login.gov's SAML issuer; `Subject/NameID` in persistent format = the user's pairwise identifier for the agency SP; a bearer `SubjectConfirmation` with `Recipient` = the resource server identifier and `NotOnOrAfter` = five minutes after issuance; `Conditions/AudienceRestriction/Audience` = the resource server identifier and nothing else; an `AuthnStatement` whose `AuthnContextClassRef` is the IAL2 ACR the service provider's sign-in asserted and whose `AuthnInstant` is that sign-in's authentication time. No `InResponseTo`. |
| **SAML-5** | The `AttributeStatement` MUST follow the existing SAML pattern: the attributes `AttributeAsserter` produces for the **agency SP's configured attribute bundle** — exactly what that agency receives when the user signs in to it directly (`uuid`, `ial`, `aal`, and its bundled identity attributes such as email, name, address, date of birth, SSN where bundled) — plus three delegation attributes: `delegation_scopes` (space-separated approved capability values for this resource), `delegation_id`, and `actor` (the service provider's issuer). `actor` is the SAML counterpart of the OAuth `act` claim (15.4). Nothing outside the agency SP's bundle is ever included. |
| **SAML-5b** | Identity attributes come from the user's decrypted PII, which Login.gov holds only in the user's live session (`Pii::Cacher`, read out-of-band by `OutOfBandSessionAccessor#load_pii`, the same path `userinfo` uses). An assertion minted or refreshed **while the service provider's Login.gov session is live** MUST include the bundled identity attributes. One minted by refresh **after that session has ended** cannot decrypt PII and MUST include only `uuid`, `ial`, `aal` and the delegation attributes; the refresh response MUST signal this with `scope` unchanged and a new `attributes: "identifiers_only"` member so the service provider can send the user back through Login.gov if it needs attributes again. Email attributes do not depend on PII decryption and are included in both cases. |
| **SAML-6** | The assertion MUST be signed with the current `SamlEndpoint` key using the existing signature options, and MUST be encrypted to the resource server's registered certificate when one is present, using the existing encryption path. |
| **SAML-7** | Every issued assertion MUST be recorded in `token_exchange_tokens` with `token_digest` = SHA-256 of the assertion `ID`, `token_format: saml2`, and the same `aud`, `scope`, grant, `delegation_id`, actor and `expires_at` as an OAuth token. Revocation (§7.5) applies unchanged. |
| **SAML-8** | `token_exchange_resource_servers` gains `token_format` (`oauth` default, `saml2`). SAML consumers validate assertions locally; **no introspection is required or expected** of them (15.5). |
| **SAML-10** | Each agency MUST declare at onboarding whether its API treats a bearer assertion as **single-use** (SAML Profiles §4.1.4.5 replay protection; the reference resource server's default) or accepts reuse within the subject-confirmation window. A service provider MUST treat assertions as single-use unless the agency says otherwise, refreshing before each call; the refresh rate limit MUST accommodate one refresh per API call. |
| **SAML-11** | The assertion's `Issuer` MUST equal the metadata `entityID` (`SamlIdp.config.base_saml_location`), the embedded `X509Certificate` MUST be byte-identical to the metadata certificate, and no Condition type other than `AudienceRestriction` MAY be emitted, because `ruby-saml`-based validators reject each of those. |
| **SAML-12** | Revocation by assertion ID MUST use `Assertion/@ID` exactly as it appears in the XML (leading underscore), since that value is what is digested; an **encrypted** encoded assertion cannot serve as the RFC 7009 `token` because its ID is inside the ciphertext — the service provider revokes such a family by refresh token, or by the ID the resource server reads after decrypting. |
| **SAML-13** | Encryption follows the **agency SP's** `block_encryption` (default `aes256-cbc`) through the existing encryption path; `none` yields a plaintext assertion even when the resource server has a certificate, so onboarding MUST NOT set `none` for a SAML agency that expects encryption. |
| **SAML-14** | `attributes: "identifiers_only"` is emitted whenever PII cannot be decrypted — including on the initial exchange when the SP session holds no cached PII — not only after the session ends. Identifiers-only keeps `uuid`, `ial`, `aal`, `email`, `all_emails` and the delegation attributes; `verified_at` is dropped with the bundle; `locale` and x509 attributes are never emitted. `ial`/`aal` attributes use the legacy classref form the agency already receives at direct sign-in, while `AuthnContextClassRef` is the verified ACR. |
| **SAML-15** | The assertion is built inside the token-row transaction, so a signing or encryption failure (for example an unparseable resource-server certificate) rolls the row back; it surfaces as a server error rather than a token-endpoint error code, and onboarding MUST validate the certificate. The prepended gem extension copies `AssertionBuilder#fresh`; a regression spec compares it byte for byte with the gem's method so a `saml_idp` upgrade fails loudly instead of drifting silently. |
| **SAML-9** | Refresh (§7) MUST re-issue an assertion with a new `ID`, `IssueInstant` and `NotOnOrAfter` when the family's `requested_token_type` is `saml2`, MUST NOT change `Audience` or `delegation_scopes`, and MUST re-check the grant (so a revoked grant stops at the next refresh). Revocation (RFC 7009) MUST accept the assertion `ID`. With the five-minute subject-confirmation window (SAML-4) a service provider that works continuously refreshes every five minutes: up to 144 assertions over the 12-hour family (§7). |

### 15.4 Where and how — reusing the existing path

**Exchange form** (`OpenidConnectTokenExchangeForm`, §5.3): add `requested_token_type` to the
permitted parameters and to `validate_grant_and_token_types`; in `mint!`, branch on it:

```ruby
def mint!
  @minted = TokenExchangeToken.create!(...)                       # as in §5.3, plus token_format:
  if saml_requested?
    @issued = DelegatedSamlAssertion.new(minted: @minted).encoded  # 15.4 below
    @minted.update!(token_digest: Digest::SHA256.hexdigest(@issued_assertion_id))
  else
    @issued = @access_token
  end
  ...
end

def response
  return error_response unless @success
  {
    access_token: @issued,
    issued_token_type: saml_requested? ? SAML2_TOKEN_TYPE : ACCESS_TOKEN_TYPE,
    token_type: saml_requested? ? 'N_A' : 'Bearer',
    expires_in: IdentityConfig.store.token_exchange_access_token_ttl_seconds,
    scope: @minted.scope,
    refresh_token: @refresh_token,
  }
end
```

**`DelegatedSamlAssertion`** (`app/services/delegated_saml_assertion.rb`) is a thin adapter, not a
builder. It exists only to supply what the controller normally gets from a request and session:

```ruby
class DelegatedSamlAssertion
  include SamlResponseOptions   # extracted from SamlIdpAuthConcern: encryption_opts,
                                # saml_response_signature_options (15.4 note)

  def initialize(minted:)
    @minted = minted
    @user = minted.user
    @agency_sp = minted.resource_server.service_provider
    @sp_identity = minted.grant.identity              # the service provider's sign-in
    @endpoint = SamlEndpoint.new(SamlEndpoint.suffixes.last)   # current signing key, as the metadata path does
    @assertion_id = SecureRandom.uuid                 # its SHA-256 is stored on the token row (SAML-7)
  end

  # RFC 8693 §3: the saml2 token is the base64url-encoded assertion itself, not a <samlp:Response>.
  def encoded
    build_asserted_attributes
    xml = encryption_opts_for(@minted.resource_server) ? builder.encrypt(sign: true) : builder.signed
    Base64.urlsafe_encode64(xml, padding: false)
  end

  private

  # The same 14 positional arguments SamlIdp::SamlResponse#assertion_builder passes today.
  def builder
    SamlIdp::AssertionBuilder.new(
      @assertion_id,                                   # reference_id -> Assertion/@ID
      SamlIdp.config.base_saml_location,               # issuer_uri
      @user,                                           # principal (reads asserted_attributes)
      @minted.resource_server.identifier,              # audience_uri  -> Conditions/AudienceRestriction
      nil,                                             # saml_request_id -> no InResponseTo (gem omits attr when nil)
      @minted.resource_server.identifier,              # saml_acs_url -> SubjectConfirmationData/@Recipient
      SamlIdp.config.algorithm,                        # raw_algorithm (SHA256)
      Saml::Idp::Constants::IAL_VERIFIED_ACR,          # authn_context_classref
      :persistent,                                     # name_id_format -> config.name_id.formats[:persistent]
      @endpoint.x509_certificate,                      # signing cert (SamlEndpoint)
      @endpoint.secret_key,                            # signing key
      @sp_identity.last_authenticated_at,              # authn_instant
      60 * 60,                                         # expiry -> NotOnOrAfter; same gem default the browser flow uses
      encryption_opts_for(@minted.resource_server),    # reuse: resource server certs + block_encryption
    )
  end

  # PII is decryptable only while the service provider's Login.gov session is live (SAML-5b).
  # OutOfBandSessionAccessor#load_pii is the same path userinfo uses; nil after the session ends.
  def decrypted_pii
    return nil if @sp_identity.rails_session_id.blank?
    OutOfBandSessionAccessor.new(@sp_identity.rails_session_id).load_pii(@user.active_profile&.id)
  end

  def build_asserted_attributes
    AttributeAsserter.new(
      user: @user, service_provider: @agency_sp, name_id_format: :persistent,
      authn_request: nil, decrypted_pii: decrypted_pii, user_session: nil,
    ).build                                           # -> the agency SP's bundle, exactly as at direct sign-in
    @user.asserted_attributes.merge!(
      delegation_scopes: { getter: ->(_) { @minted.scope } },
      delegation_id:     { getter: ->(_) { @minted.grant.delegation_id } },
      actor:             { getter: ->(_) { @minted.service_provider.issuer } },   # SAML counterpart of `act`
    )
  end
end
```

Two small generalizations of existing code make this possible, both additive:

- `AttributeAsserter` currently derives the authentication context from `authn_request`. Allow
  `authn_request: nil` and take the asserted IAL/AAL from the identity the exchange already has
  (`sp_identity.ial`, `sp_identity.aal`). Same result for today's callers.
- Move `saml_response_options`, `encryption_opts` and `saml_response_signature_options` from
  `SamlIdpAuthConcern` into a module that takes the SP as an argument instead of reading
  `saml_request_service_provider`. `SamlIdpAuthConcern` includes the module; behavior is unchanged.

`SamlIdp::AssertionBuilder` is the same class `SamlIdp::SamlResponse#assertion_builder` instantiates
for every SAML sign-in today, with the same argument list; the only difference is that audience,
recipient and request ID are supplied by the exchange rather than an AuthnRequest.

The third change is a one-line fix in the `saml_idp` gem (`18F/saml_idp`, tag `v0.25.3-18f`),
which Login.gov already maintains and `identity-idp` already depends on. Verified against `lib/saml_idp/assertion_builder.rb` at that tag, the bearer
`SubjectConfirmationData` always carries `InResponseTo`; with no AuthnRequest that would be emitted
as an empty, schema-invalid `InResponseTo=""`. The same builder also fixes `SubjectConfirmationData/@NotOnOrAfter` at three minutes
(`not_on_or_after_subject`), which is right for a browser POST but not for an assertion a server
holds for an hour (SAML-4). Both are handled by one small, backward-compatible change: omit
`InResponseTo` when `saml_request_id` is nil, and let a caller supply the subject-confirmation
window:

```ruby
# lib/saml_idp/assertion_builder.rb (saml_idp gem)
def initialize(..., expiry = 60 * 60, encryption_opts = nil, subject_confirmation_expiry: 3 * 60)
  ...
end

# inside Subject → SubjectConfirmation
data = { NotOnOrAfter: iso { now + subject_confirmation_expiry }, Recipient: saml_acs_url }
data[:InResponseTo] = saml_request_id if saml_request_id      # omit when nil
confirmation.SubjectConfirmationData '', data
```

`DelegatedSamlAssertion` passes `subject_confirmation_expiry: 5 * 60`. Every existing SAML sign-in
has a request ID and takes the 3-minute default, so today's output is unchanged. The gem is retagged
and the `Gemfile` pin updated.

#### Parity with the OAuth `act` claim

RFC 8693 §4.1 defines `act` as "a means within a JWT to express that delegation has occurred and
identify the acting party," and §1.1 says representations in other token formats are out of its
scope. In the delegated assertion the acting party is carried as the `actor` attribute:

| RFC 8693 (OAuth / introspection) | SAML 2.0 (this item) |
|---|---|
| `act: { "sub": <service provider> }` — top-level claim | `<saml:Attribute Name="actor">` = the service provider's issuer |
| `sub` stays the user | `<saml:Subject>` stays the user |
| Nested `act` for chains | Not needed: chained delegation is a non-goal (§1.2), so `actor` is a single value |
| Consumers "MUST only consider … the party identified as the current actor" | An API that reads `actor` treats the call as delegated by that service provider (15.7) |
| `may_act` (who is *allowed* to act) | No assertion-level equivalent; the `token_exchange_grants` table is the authorization record for both formats |

**Why an attribute, and not SAML's Delegation Restriction condition.** SAML does have a purpose-built
construct for this — the OASIS *SAML V2.0 Condition for Delegation Restriction*, a `<saml:Condition>`
listing delegates — and it is the closer structural match to `act`. It was considered and not used,
deliberately. SAML Core §2.5.1 requires a relying party to treat an assertion containing a Condition
type it does not understand as *Invalid*, so using the condition would make every delegation-unaware
agency API reject delegated assertions until it shipped code to parse it. An attribute is the
opposite: an API that is delegation-aware can read `actor` and apply its own policy; one that is not
still accepts the assertion. That is the behavior wanted here, because **which service providers may
act for an agency's users is being agreed with each agency manually** (the agency form's 3.4
answer), not enforced at the API by parsing the assertion. The same choice applies to the
`SubjectConfirmation` `NameID` duplicate the OASIS specification recommends: it is not emitted,
since it would only matter to a consumer of the condition.

If a future agency wants the fail-closed behavior, the condition can be added alongside the
attribute without changing anything above; the gem's assertion builder would need a small extension to emit
it, and only that agency's assertions would carry it.

**Refresh form** (§7.3): `TokenExchangeRefreshToken` records `requested_token_type`;
`mint_from_family!` calls `DelegatedSamlAssertion` when it is `saml2`.

**Migration:** `add_column :token_exchange_resource_servers, :token_format, :string, default: 'oauth'`
and `add_column :token_exchange_tokens, :token_format, :string, default: 'oauth'`, both
`comment: 'sensitive=false'`.

### 15.5 Enforcement and revocation

A SAML assertion is self-contained. The resource server validates it locally — signature against
`/api/saml/metadata`, `Audience`, `NotOnOrAfter`, `Recipient` — and reads `delegation_scopes` to
decide which endpoints the call may reach. That is the same scope the user approved, applied the
same way as `scope` from introspection. **SAML consumers are not asked to call Login.gov per request;
no introspection is required of them.** This is the deliberate difference from the OAuth path and
the reason an agency would choose SAML.

The consequence is accepted, not mitigated away: **a revoked grant's assertion remains usable at
the API until it expires.** In practice the window is shorter than the assertion's lifetime whenever
the service provider treats assertions as single-use (SAML-10, REF-IMPL-12): it refreshes before every
repeat presentation, Login.gov refuses that refresh because the grant is gone, and the service provider
learns of the revocation at its next call. Only an assertion already delivered to the API and not yet
presented can still be used, once. At validators that enforce `SubjectConfirmationData/@NotOnOrAfter`
(the normal case) that is five minutes; at one that checks only `Conditions` it is up to one hour,
the same window a browser-flow SAML assertion has today. Revocation takes effect at the next
refresh (SAML-9 re-checks the grant) or at expiry, whichever comes first. The account page shows the assertion's "active until" time so the user sees
the window. Introspection by assertion ID remains available to any agency that wants it (RFC 7662
does not restrict token format), but it is optional and not part of the onboarding commitment.

**Why SAML-12–SAML-15.** Found while building and validating the issuer against the reference SAML
resource server (whose validator accepted the encrypted and plaintext assertions unmodified). They are the
seams where the reused browser-flow code (encryption options, `AttributeAsserter`, the gem's builder) meets
the server-to-server use.

**Why SAML-10 (learned from the reference SAML resource server).** SAML
Profiles §4.1.4.5 tells a relying party to ensure a bearer assertion is not replayed, and the
reference resource server does so by default (it remembers assertion IDs until `NotOnOrAfter` and
rejects repeats; `REPLAY_PROTECTION=false` turns it off). That is at odds with a service provider
presenting one assertion for several API calls inside the five-minute window. Two consistent
positions are possible and the agency form should ask which one an agency takes: (a) the API
treats each assertion as single-use and the service provider refreshes before every call (up to one
assertion per call, well within the refresh rate limit), or (b) the API accepts reuse within the
subject-confirmation window and relies on the five-minute expiry. The reference apps default to
(a). Two further validator behaviors to expect at agencies using `ruby-saml`: `Issuer` must equal the
metadata `entityID` (`SamlIdp.config.base_saml_location`), and when the assertion embeds an
`X509Certificate` it must be byte-identical to the metadata certificate (`saml_idp`'s signature
builder already does this). Validators that follow SAML Core §2.5.1 reject any Condition type they
do not understand, which confirms the choice of an `actor` attribute over a Delegation Restriction
condition.

### 15.6 Touches to other sections when this item is built

Listed here so the rest of the document stays as specified until the item is scheduled.

| Section | Change |
|---|---|
| §3.2 `token_exchange_resource_servers` | Add `token_format` (SAML-8) |
| §3.3 onboarding YAML / agency form | One field per resource server: token format (`oauth` or `saml2`); certificate already collected |
| §5.3 exchange form | `requested_token_type` parameter and the branch in `mint!` / `response` (15.4) |
| `saml_idp` gem (`18F/saml_idp`) | One-line fix: omit `InResponseTo` when `saml_request_id` is nil; new gem tag pinned in `Gemfile` |
| §5.4 discovery | No standard metadata key exists for supported `requested_token_type` values; document in the integration guide only |
| §7 refresh / revocation | Family remembers `requested_token_type`; revoke by assertion ID (SAML-9) |
| §8 Attempts | `delegated-access-token-issued` and `-refreshed` events gain `token_format` |
| §9 billing | None — rows key on the grant and `delegation_id` |
| §14 reference implementations | Service provider: a "request SAML" toggle. Resource server: a SAML branch that fetches IdP metadata, validates with `ruby-saml`, reads `actor`, `delegation_scopes` and `delegation_id` from the attribute statement, and enforces `delegation_scopes` per endpoint, with no call to Login.gov. Harness scenarios: assertion accepted; assertion for resource A rejected at resource B on `Audience`; revoked grant → assertion still valid until expiry, next refresh refused (documents the accepted window); refresh after the service provider's session ended → identifiers-only assertion (SAML-5b). |

### 15.7 What the agency API must do (SAML consumers)

1. Register with `token_format: saml2` and a certificate for encryption (§3). Note that the
   assertion carries the same identity attributes the agency receives at direct sign-in (SAML-5),
   so its existing attribute handling applies.
2. Trust Login.gov's SAML metadata at `/api/saml/metadata` — most SAML relying parties already do.
3. Validate signature, `Audience` (must equal its own identifier), `NotOnOrAfter`, and `Recipient`.
4. Enforce `delegation_scopes` per endpoint. A delegation-aware API SHOULD also read `actor` and
   treat the call as delegated access by that service provider, applying any policy it has for
   third parties (for example, reads only). An API that does not read `actor` still accepts the
   assertion; which service providers may act for the agency's users is agreed with the agency
   through the onboarding process (agency form, 3.4), not enforced by the assertion. `delegation_scopes`
   and `delegation_id` are what make an assertion a delegated one and MAY be required by an API that
   accepts only delegated assertions; `actor` MUST be observed and logged when present and MUST NOT
   by itself be a reason to reject (the same rule as `act` in §6.3 item 8).
5. Never accept a SAML assertion issued to another audience, and never accept an assertion from
   the ordinary sign-in flow as delegation.

### Decisions (2026-09-28)

- **Identity attributes: included**, following the existing SAML pattern — the agency SP's
  configured bundle, exactly as at direct sign-in (SAML-5), subject to the live-session constraint
  on PII (SAML-5b).
- **Revocation: no introspection.** Assertions keep the browser flow's one-hour `Conditions`
  lifetime with a five-minute subject-confirmation window, and are validated locally; a revoked
  grant is refused at the next refresh (SAML-4, SAML-9, 15.5).
- **Attributes on refresh after the session ends: identifiers only**, with the response flagging
  it, rather than persisting decrypted PII for the refresh family (SAML-5b).
- **`saml1`: not supported.** Only `saml2` is accepted (SAML-1).
- **Delivery: server return only.** The assertion is returned to the service provider's server in
  the exchange response; browser-POST (IdP-initiated) delivery is out of scope.

### Open question (resolved 2026-09-29)

- The OAuth path returned identifiers only from introspection while SAML assertions carried the agency
  SP's bundle. Resolved by INT-10: introspection returns the userinfo-shaped claims for the agency SP's
  bundle, so the two formats are equivalent for agencies.

### 15.8 Amendments of 2026-10-09 (SAML interview)

Where a row below conflicts with §15.3–§15.7 or the decisions of 2026-09-28, this subsection governs. Decided with the product owner on 2026-10-09 (implementation plan D44, D45).

| ID | Requirement |
|---|---|
| **SAML-1** (amend) | `requested_token_type` is REQUIRED on every exchange (EXC-21); an absent value fails with `invalid_request`, not as an OAuth default. `urn:ietf:params:oauth:token-type:access_token` mints an OAuth token (§5), `urn:ietf:params:oauth:token-type:saml2` a SAML assertion; any other value fails with `invalid_request`. |
| **SAML-3** (amend) | The service provider chooses the format. For now the resource server does not declare which formats it accepts: `token_format` on `token_exchange_resource_servers` is informational and a `saml2` request for an `oauth` API is honored. **Flagged for review:** keeping the choice with the service provider may be right, or Login.gov could select the format from the `token_format` of the API named in `resource` and refuse a mismatch with `invalid_target`; `token_format` is kept so that check can be added without a migration. |
| **SAML-4** (amend) | `Conditions/@NotOnOrAfter` is issuance + **5 minutes** (not one hour), with `NotBefore` = issuance − 5 s; `SubjectConfirmationData/@NotOnOrAfter` stays issuance + 5 minutes. The two windows coincide, so no validator accepts an assertion past five minutes and the revocation delay of §15.5 is bounded by the same figure. |
| **SAML-6** (confirmed) | Always signed; encrypted to the resource server's registered certificate when one is present (SAML-13 governs the algorithm). |

**Why SAML-4 (amend).** The one-hour `Conditions` window came from the browser flow's default and only mattered for validators that ignore the subject-confirmation window; with refresh every five minutes (SAML-9) nothing legitimate needs an assertion older than that, and the shorter window means a revoked grant is dead at every validator within five minutes.

---

## 16. Third-party-initiated login (reference applications)

This section is not identity-idp work. It specifies the second integration pattern the reference
applications demonstrate, so that America.gov and the agencies have a working example of both
patterns side by side and can see where each fits. Nothing in Login.gov changes for it: the agency
signs the user in as its own service provider, exactly as a direct sign-in, and the existing Login.gov
session gives single sign-on.

**Standard.** [OpenID Connect Core 1.0 §4, Initiating Login from a Third Party](https://openid.net/specs/openid-connect-core-1_0.html#ThirdPartyInitiatedLogin).
The third party sends the user's browser to the relying party's *login initiation endpoint* with
`iss` (the OP to use), `login_hint` (an opaque hint), and `target_link_uri` (where to send the user
afterwards). The relying party then starts its ordinary authentication request to that OP. For the
SAML-consuming agency the same initiation request starts the agency's normal SAML AuthnRequest;
§4 is an OpenID Connect pattern applied, unchanged, to a SAML service provider.

### 16.1 When it fits

Use it when the agency must interact with the user directly in its own service, require its own
assurance level, or run its own workflow with the user present. Use the STS (§3–§9) when the
service provider calls the agency API from its server, combines several agencies, continues while
the user is away, or passes attributes the service provider itself must not see. A business case may
use both. The Department of State passport case uses the STS (the functional requirements, §11).

### 16.2 Requirements

| ID | Requirement |
|---|---|
| **TPL-1** | The reference service provider (America.gov) MUST start the flow with a browser redirect to the agency's `initiate_login_uri` carrying `iss` = Login.gov's issuer URL, `login_hint` = a UUID the service provider generates for this hand-off, and `target_link_uri` = the service provider's own return URL (`/third_party/return`). |
| **TPL-2** | `login_hint` is a correlation identifier only. It MUST carry no identity, MUST be single-use, MUST expire (ten minutes in the reference), and the service provider MUST accept a return only when the hint matches an outstanding hand-off it recorded server-side. The agency learns who the user is only from its own Login.gov sign-in; neither party treats the hint as identity. |
| **TPL-3** | Each agency reference app MUST expose `GET /initiate_login`, MUST refuse the request unless `iss` equals the Login.gov issuer it is configured to use (§4: the RP MUST verify the issuer is one it trusts, or a forged `iss` sends the user to an attacker's OP), and MUST refuse unless `target_link_uri` matches an allow-list of exact origins (§4: the RP MUST verify this value to prevent open redirects). No wildcards; `https` or the explicit local-development origins only. |
| **TPL-4** | On a valid initiation the agency MUST remember `login_hint` and the validated `target_link_uri` in its session and start its ordinary Login.gov sign-in: the OIDC agency its usual authorization code request, the SAML agency its usual AuthnRequest, with the scopes, attributes and ACR it uses for a direct sign-in. The hint is not forwarded to Login.gov. |
| **TPL-5** | When the agency's sign-in completes it MUST send the user to the remembered `target_link_uri` with `login_hint` (the same UUID), `iss` (the agency's own client_id or SAML entityID, so the service provider knows which agency returned the user) and `status` (`signed_in` or `failed`), then clear the hand-off so it cannot be replayed. An OIDC agency MAY do this with an HTTP redirect from its callback. A SAML agency MUST NOT redirect to the third party straight from its assertion consumer: Login.gov's SAML POST-binding page carries `Content-Security-Policy: form-action 'self' <ACS>`, and Chrome applies `form-action` to every redirect that follows a form submission, so a cross-origin redirect from the ACS is blocked and the user is left on Login.gov's page. The SAML agency instead answers the ACS POST with its own page that continues to `target_link_uri` (an immediate refresh plus a visible link), which is a new navigation under the agency's own policy. |
| **TPL-6** | The agency MUST show on its signed-in page that the session was started by a third party, and MUST NOT include any identity data in the return redirect; what the service provider learns is only that the hand-off it started completed. |
| **TPL-7** | The pattern is browser-only. The service provider MUST NOT hold a token for the agency, MUST NOT call the agency's systems directly, and the agency's Attempts API events, billing and consent are those of a direct sign-in. The reference apps MUST state this difference from delegated access in their user interface and documentation. |

**Why a plain UUID rather than a signed hand-off.** §4 defines the three parameters and no
integrity protection. The reference implementation uses the plain parameters so the pattern is shown
as the standard defines it, with the two §4 MUST-verify rules (TPL-3) and a single-use server-side
hint (TPL-2) as the controls. The hint ties the return to the America.gov browser session that
started it, which is what prevents a result being attached to a different person's session. A signed
hand-off statement (carrying task context or a return address the agency should trust) remains an
option for a production integration and is noted in the functional requirements (Appendix C there);
it is not required for the flow to be correct.

### 16.3 Where

| Repository | Change |
|---|---|
| `identity-sts-sinatra` | `third_party_login.rb` (hint, initiation URL, hand-off record and match), routes `POST /third_party/start`, `GET /third_party/return`, dashboard section, configuration `THIRD_PARTY_LOGIN_TARGETS` and `THIRD_PARTY_RETURN_URI`, documentation. |
| `identity-oidc-sinatra` | `GET /initiate_login` with the `iss` and allow-list checks, hand-off stored in session, redirect after `/auth/result`, `THIRD_PARTY_TARGET_LINK_ALLOWLIST`. |
| `identity-saml-sinatra` | Same, except that `POST /consume` answers with the agency's own return page (refresh plus link) instead of a redirect, because of Chrome's `form-action` handling of the SAML POST binding (E34). |
| `identity-idp` | None. |

**Amended 2026-10-09 (D57).** §16.1's "calls the agency API from its server" reads "from its browser": the service provider is a browser public client, so the STS fits when the service provider calls agency APIs from the person's browser with its own tokens, combines agencies, or continues through refresh while the person is away from the agency. In §16.3 the `identity-sts-sinatra` initiator is page code: the hand-off record of TPL-2 (`login_hint` UUID, ten-minute expiry, single use) is kept in the browser's session storage, since there is no server session, and `THIRD_PARTY_LOGIN_TARGETS` and `THIRD_PARTY_RETURN_URI` move into the non-secret JSON configuration. TPL-1 to TPL-7 are otherwise unchanged; the agency side is not affected.

---

## 17. Per-site keys (ported)

This section mirrors implementation plan 5.16 at the design level. The feature is independent of
§3–§9: it is ported from pull requests #13618 and #13619 of `18F/identity-idp` onto the branch
`delegated-access-site-keys` at the top of the stack (D56), and nothing releases a site key yet. The
release of the sealed key on OIDC authorization and the recovery paths after a password reset or with
the personal key are the later pull requests of the same series (#13620 to #13622) and are not ported.

**What a site key is.** A key unique to a user and a service provider, the same on every device, and
delivered only to the service provider's browser: the browser generates a P-256 key pair with WebCrypto,
sends the public JWK with the authorization request, and receives the site key sealed to that JWK. Login.gov
derives the key from a per-user root it can open only with the user's password.

### 17.1 Classes

| Class | Role |
|---|---|
| `SiteKeys::RecipientJwk` | Parses `site_key_jwk`: base64url JSON of a P-256 public JWK. Accepts and ignores the WebCrypto `exportKey('jwk')` metadata (`ext`, `key_ops`, `alg`, `kid`, `use`); rejects any other member including a private `d`, off-curve points and coordinates that are not 32 bytes. |
| `SiteKeys::Sealer` | Encrypts a key to the recipient JWK with ECDH-ES, HKDF-SHA256 and AES-256-GCM. HKDF info and GCM AAD are both `"login.gov site key wrap v1\n<client_id>"`; output is base64url JSON `{v, epk, iv, ct}`. Raises `SiteKeys::SealError`. |
| `Encryption::DecipherError` | Raised by `Encryption::AesCipher` and `Encryption::AesCipherV2` when a payload fails authentication, so callers can distinguish a wrong key from other failures. |
| `SiteKeys::RootCipher` | Wraps and unwraps the root with `Encryption::Encryptors::PiiEncryptor` (scrypt of the password + KMS), the profile-PII scheme. A wrap that fails authentication raises `SiteKeys::RootMismatchError`; any other failure raises `Encryption::EncryptionError`. |
| `SiteKeys::Vault` | Unlocks the root with the password (`unlock`, creating one only when `create:` is set), caches it KMS-encrypted in the session (`encrypted_site_key_root`) with a fingerprint of the stored wrap (`site_key_root_fingerprint`) so the session re-locks when another session changes it; `replace!` under a row lock, `wrap_cached_root` and `store_root_or_forget!` for password change, `needs_password?` and the `site_key_root_unavailable` marker for the password page. |
| `SiteKeyConcern` | Controller concern: `unlock_site_key_root` at password entry (sign-in, password capture, sign-up password) with `repair: false` before the second factor; after it, a wrap that fails under a just-verified password is replaced unless a concurrent password change explains it. `site_key_root_wanted?` is `current_sp.site_key_allowed?`. |
| `SiteKeyRoot` | Model; `forget_password!` deletes the row, used by every password reset path. |

### 17.2 Table and column

`site_key_roots` (migration `20261003110000`): `user_id` (unique index; foreign key to `users` with `on_delete: :cascade`), `encrypted_root` (text, sensitive; the `PiiEncryptor` output of the 32-byte root), timestamps. `service_providers.site_key_allowed` (boolean, default `false`, migration `20261003110001`): set only from `service_providers.yml` (and `service_providers.localdev.yml` locally); `ServiceProviderUpdater` ignores it so the Dashboard cannot turn it on. Both migrations predate the delegation migrations (`20261009…`) in timestamp order.

### 17.3 Configuration

`site_key_enabled` (boolean, default `false`) gates everything: when off, no root is created, unlocked or stored and `site_key_allowed` has no effect. No other key is added.

### 17.4 Lifecycle

1. Sign-in to a service provider with `site_key_allowed` creates the root (32 random bytes) if the user has none, wrapped under the password just entered; sign-in to any other service provider unwraps an existing root but never creates one.
2. The root is unwrapped before the second factor and kept KMS-encrypted in the session; it is never written to the session or logs in the clear.
3. Password change re-wraps the cached root in the same transaction as the password update under a row lock on `site_key_roots`; if the root is locked in the session the password page asks for the current password first; a root that cannot be re-wrapped is deleted.
4. Every password reset path (`ResetPasswordForm`, `PasswordResetFromDisavowalForm`, `ResetUserPassword`) deletes the root; user deletion cascades.
5. Analytics: `site_key_root_created` (`replaced`) and `site_key_root_unlock_failed` (`error`, `root_replaced`); no key material is logged.

Known limitation carried from the source: a transient unlock failure followed by a password change deletes the root; the follow-up pull requests change this to dropping only the password wrap.

### 17.5 Relation to delegated access

Independent code paths: nothing in §3–§9 reads a site key root and nothing here reads a grant, a token or a resource server. The sealed key goes only to the service provider's browser, which fits the public-client baseline (§5.5, E53): the page that holds the DPoP key would hold the site key. Whether a released site key is ever tied to a delegation is a question for the follow-up pull requests.

---

## Appendix A — Open decisions

| Decision | Options | Recommendation |
|---|---|---|
| ~~Adopt sender-constrained tokens (DPoP)?~~ | — | **Decided 2026-10-08:** adopted (option B). Login.gov verifies proofs and binds at exchange and refresh; agencies set `dpop_required` per resource server; required for APIs reached from a browser-based service provider such as America.gov. See EXC-9, INT-4, REF-3, §6.3 item 11, Appendix C. **Amended 2026-10-09:** the per-resource-server flag is removed; binding follows the client type (EXC-9 as amended, E82). |
| ~~For SAML-consuming APIs (§15), accept the revocation delay or require introspection?~~ | — | **Decided 2026-09-28:** no introspection; one-hour `Conditions` with a five-minute subject-confirmation window; revocation at next refresh (§15.5) |
| ~~Should introspection return identity attributes (narrowed to the owning SP's `attribute_bundle`) or only `sub`?~~ | — | **Decided 2026-09-29:** attributes, as userinfo-shaped claims limited to the agency SP's bundle (INT-10); the agency behaves as for a direct sign-in, introspection being the only added step. Was: SAML assertions (§15, SAML-5) carry the agency SP's bundle, so parity argues for returning the same from introspection |
| ~~Should sign-out at Login.gov revoke delegated families?~~ | — | **Decided 2026-10-09:** no (REF-6, REF-5 as amended); the family runs 12 hours from the first exchange for every grant, remembered or not; the account page offers revocation (ACC-2) |
| ~~How is proofing attributed across the service provider's and the agency's partners when both see the same proofing in one month?~~ | — | **Decided 2026-10-09:** every agency that received a delegated token in that sign-in, proofing included; the service provider's sign-in is waived (BIL-8 as amended, E78) |
| Should the IdV outcomes report exclude delegated rows? | yes / no | Yes |
| ~~Per-service provider refresh lifetime below 12 hours for `read_write` scopes?~~ | — | **Decided 2026-10-09:** yes, configurable per resource server (`max_family_seconds`, `max_access_token_seconds`) and per service provider; never longer (REF-5 as amended) |
| ~~Should a target agency approve specific service providers per scope?~~ | — | **Decided 2026-10-09:** `allowed_delegation_service_providers` on the application; empty means any approved service provider (ONB-2 as amended) |
| ~~When a service provider adds a new scope and the user has remembered grants, show only the new one or the full pre-filled list?~~ | — | **Decided 2026-10-09:** full requested list, all rows checked and disabled, already-approved rows marked, new rows marked new (CON-7 as amended) |

## Appendix B — Endpoint summary

| Endpoint | Method | Auth | Standard | Section |
|---|---|---|---|---|
| `/openid_connect/authorize` | GET | user session | OIDC Core | §4 |
| `/api/openid_connect/token` (`authorization_code`) | POST | `private_key_jwt` or PKCE | RFC 6749, 7523 | existing |
| `/api/openid_connect/token` (`refresh_token`) | POST | `private_key_jwt` | RFC 6749 §6, 9700 §4.14 | §7 |
| `/api/openid_connect/token` (`token-exchange`) | POST | `private_key_jwt` | RFC 8693 §2.1, 8707 | §5 |
| `/api/openid_connect/introspect` | POST | `private_key_jwt` (resource server) | RFC 7662 | §6 |
| `/api/openid_connect/revoke` | POST | `private_key_jwt` | RFC 7009 | §7 |
| `/api/attempts/poll` | POST | `Bearer <issuer> <secret>` | RFC 8936, SSF | §8 (existing) |
| `/account/delegated_access` | GET / DELETE | user session | — | §4.7 |
| Agency reference apps `/initiate_login` | GET | none (browser redirect; `iss` and `target_link_uri` validated) | OpenID Connect Core 1.0 §4 | §16 |
| Reference service provider `/third_party/start`, `/third_party/return` | POST / GET | user session | OpenID Connect Core 1.0 §4 | §16 |
| Reference service provider `/delegated/*`, reference resource server `/records` | — | see §14 | RFC 6750, 7523, 7662 | §14 |

**Amended 2026-10-09 (D57, D59).** `/api/openid_connect/token`, `/api/openid_connect/introspect` and `/api/openid_connect/revoke` answer `OPTIONS` preflights for origins that match a registered redirect URI, with any request header; the public client authenticates with a DPoP proof, not `private_key_jwt`, on all three (§5.5). The reference service provider's `/delegated/*` routes no longer exist as server routes: they are page states in the browser client. The reference resource servers add CORS for the service provider's origin (allow `Authorization`, `DPoP`, `Content-Type`; expose `WWW-Authenticate`).

---

## Appendix C — Item 8: Sender-constrained tokens (DPoP, RFC 9449)

**Adopted 2026-10-08** as option B below, and built: EXC-9, INT-4, INT-9, REF-3 and DISC-2 now
state the normative behavior; §6.3 item 11 states the resource server's obligations. The reason it
moved from optional to required is the America.gov client design: America.gov's servers authenticate
the exchange with `private_key_jwt` but hold no user tokens; the tokens live in the user's browser,
which generates an ephemeral key, signs the proofs, and calls the agency APIs. A bearer token in a
browser is exposed to any script on the page; binding it to a non-extractable browser key is what
makes that design acceptable to Login.gov and to the agencies. The analysis below is kept as the
rationale.

**How it is built.** `DpopProofVerifier` (one check per RFC 9449 §4.3 item, `jti` replay in Redis
for the acceptance window, `iat` accepted 60 s back and 10 s forward, no `DPoP-Nonce` yet) is called
by the exchange and refresh forms with the `DPoP` request header, after every other check. The
thumbprint is stored on `token_exchange_tokens.dpop_jkt`, copied forward by
`TokenExchangeToken.mint_from_family!`, returned by introspection as `cnf.jkt` with
`token_type: DPoP`, and placed in a SAML assertion as the `dpop_jkt` attribute. Local fixtures mark
the two reference resource servers `dpop_required: true` so the end-to-end harness exercises the
mandatory path. The reference apps generate proofs (service provider, one key per signed-in session)
and verify them (both resource servers).

**Amended 2026-10-09 (D46, D47).** Option B's per-resource-server opt-in is withdrawn. Since the service provider is a public client (§5.5), binding is a property of the client type: every token issued to a public client is bound (EXC-17) and no token issued to a confidential client is, so `dpop_required` has nothing left to decide. The DPoP feature's migration drops the column; the fixture key and the seeder support go with it, and the harness exercises the bound path because its service provider is public. Accepted proof algorithms are `ES256` and `RS256` (DISC-2). The C.5 table and the C.6 rows below are kept as the record of the analysis.

**Amended 2026-10-10.** The acceptance window above is not what was built: `DpopProofVerifier` accepts `iat` within `dpop_proof_max_age_seconds` (300 by default) either side of now, so ±300 s rather than 60 s back and 10 s forward, and keeps each `jti` for twice that window, since a proof with a future `iat` at the edge of the window stays acceptable for two windows (E98). The thumbprint is stored on `identities.dpop_jkt` at the authorization request and on `token_exchange_tokens.dpop_jkt` at the exchange; `mint_from_family!` is not built yet (§7).

### C.1 What it is

Today's delegated access token is a **bearer** token (RFC 6750): whoever holds it can use it.
DPoP ("Demonstrating Proof of Possession", RFC 9449) binds the token to a public key the service
provider holds. Every time the service provider uses the token — at the token endpoint or at an
agency API — it also sends a short signed JWT (the *proof*) showing that it holds the matching
private key and that the proof was made for *this* request (HTTP method, URL, time, and a hash
of the token). A token stolen without the key is useless.

### C.2 What the core design already protects, and what DPoP adds

| Asset | Protection without DPoP (core) | What DPoP adds |
|---|---|---|
| Service provider's sign-in access token | Only usable at `userinfo`; exchange requires the SP's private key (`private_key_jwt`, EXC-2) | Nothing material — client authentication already sender-constrains the exchange |
| Refresh token (12 h) | Refresh requires the SP's private key (REF-2); rotation and reuse detection (REF-4); hashed at rest (REF-7) | Nothing material — RFC 9700 §4.14.2 treats client authentication as sufficient for confidential clients |
| **Delegated access token (15 min)** | Short life (REF-5); one API only (EXC-4); instant revocation via introspection (INT-2) | **This is the gap.** A token copied from the SP's server, a proxy, or the agency API's own request logs is usable at that one API for up to 15 minutes. With DPoP it is useless without the SP's key. |

RFC 9700 §4.10.1 says access tokens *SHOULD* be sender-constrained. High-assurance profiles
(FAPI 2.0) say *MUST*. A delegated token carries an identity-proofed user to a government API,
which is the kind of credential those profiles have in mind. Against that, the exposure window
is 15 minutes at a single API, revocable at any moment.

### C.3 Who bears the cost

| Party | Work | Size |
|---|---|---|
| **Service provider** | Generate a key pair once; attach a proof JWT to each exchange, refresh and API call (RFC 9449 §4). | Moderate. A small helper; they already manage a key for `private_key_jwt`. |
| **Login.gov** | Verify the proof at exchange and refresh; store the key thumbprint (`dpop_jkt`, already reserved in §5.2); return `cnf.jkt` from introspection; advertise in discovery. | Moderate, one-time. |
| **Agency API (resource server)** | On **every request**: parse the proof, verify its signature with the embedded key, check `htm` and `htu` match this exact method and URL, check `iat` is fresh, keep a `jti` replay cache, check `ath` equals the SHA-256 of the token, and confirm the key's thumbprint equals `cnf.jkt` from introspection (§4.3). Refuse a bound token presented as plain `Bearer` (§7.1). | **Largest.** A JWT library, a replay cache, and URL normalization behind load balancers and gateways — a well-known source of bugs. |

The agency API's part cannot be moved to Login.gov: introspection validates the *token*, but the
proof is bound to the specific request to the API, and only the API sees that request. What
Login.gov can do is ship the verification code in the reference resource server (§14.4).

The party that bears the risk (the agency's data) is the same party that bears most of the cost
(the agency's API). That argues for making it the **agency's choice per resource server**, not a
global rule.

### C.4 Trade-offs

**For adopting it**
- Closes the only remaining bearer-token exposure in the design.
- Aligns with RFC 9700 and high-assurance profiles; easier to defend in a security review.
- The token model already has room for it (`dpop_jkt`, `token_type`), so Login.gov's side is
  incremental.
- Reference implementations can carry the hard part for agencies.

**Against adopting it now**
- Adds a new, non-trivial obligation to every opting-in agency API, on the hot path of every
  request. Agencies are already taking on introspection; two new mechanisms at once slows
  adoption.
- Proof verification has sharp edges: `htu` behind proxies, clock skew, replay-cache sizing.
  Mistakes produce false rejections that look like Login.gov outages to users.
- If an agency API ignores `cnf` (does not implement DPoP), a bound token silently degrades to
  bearer at that API. Partial adoption gives a false sense of coverage unless Login.gov refuses
  to issue bound tokens for APIs that haven't declared support — which option B below does.
- Marginal risk reduction is bounded: 15 minutes, one API, revocable.

**Alternative: mutual TLS (RFC 8705).** Binds the token to the client's TLS certificate instead
of an application-layer proof. It puts no per-request JWT work on the API, but it requires
client-certificate termination at the edge; Login.gov sits behind CloudFront and an ALB, where
that is awkward, and agency API gateways vary widely. DPoP is the more portable choice if
sender-constraining is wanted.

### C.5 Options for the team

| Option | Description | When it fits |
|---|---|---|
| **A. Not now, keep the door open** | Ship the core as written. `dpop_jkt` stays reserved and null. Revisit after the first partners are live. | The first agencies are read-only APIs, or partner capacity to implement is the bottleneck. |
| **B. Login.gov supports it; agencies opt in per resource server** (recommended if adopting) | Login.gov implements verification and binding. A `dpop_required` flag on `token_exchange_resource_servers` makes Login.gov refuse an exchange for that API without a valid proof. APIs that don't opt in receive ordinary bearer tokens and need no DPoP code. | Some agencies want it (for example `read_write` APIs) and others don't; lets each decide. |
| **C. Mandatory** | Every exchange requires a proof; every API must verify. | A policy decision that all delegated access must be sender-constrained, accepting slower onboarding. |

If B is chosen, recommend `dpop_required: true` at onboarding for `read_write` resource servers.

### C.6 If adopted: the exact changes

**Requirements to add or amend**

| ID | Text |
|---|---|
| **EXC-9** (replace) | Login.gov MUST accept an RFC 9449 `DPoP` header on the token-exchange and refresh grants. When present and valid (§4.3: signature, `htm`, `htu`, `iat`, unused `jti`), the minted token and its refresh family MUST be bound to the proof key by storing its JWK thumbprint (`dpop_jkt`), and `token_type` MUST be `DPoP`. If the resource server has `dpop_required: true` and no valid proof is present, the exchange MUST fail with `invalid_dpop_proof` (RFC 9449 §5). |
| **INT-4** (amend) | The active response MUST include `cnf: { jkt: ... }` for key-bound tokens (RFC 9449 §6, RFC 7800). |
| **REF-3** (amend) | The refreshed access token inherits the family's `cnf`; the refresh request MUST carry a proof signed by the bound key. |
| **DISC-2** (activate) | `dpop_signing_alg_values_supported: ["ES256", "RS256"]`. |
| **ONB-2** (amend) | `token_exchange_resource_servers.dpop_required` boolean, default false, `sensitive=false`. |
| **RS-DPOP-1** (new, §6.3) | A resource server whose tokens may be key-bound MUST verify the proof on every request per RFC 9449 §4.3 and MUST refuse a bound token presented with the `Bearer` scheme (§7.1). |

**Amended 2026-10-09 (D47).** The `dpop_required` clauses of EXC-9 (replace) and ONB-2 (amend) above, and the migration line below, are superseded: see §5.6 (EXC-9 as amended), §3.4 (ONB-2 as amended) and §13 item 5.

**Code, by file**
- `app/forms/openid_connect_token_exchange_form.rb`, `..._refresh_token_form.rb`: accept
  `dpop_proof:` from `request.headers['DPoP']` (passed from `TokenController#build_form`); add
  `validate :validate_dpop`; set `dpop_jkt` on mint; `token_type: @dpop_jkt ? 'DPoP' : 'Bearer'`.
- New `app/services/dpop_proof_verifier.rb`: decode the proof (`typ: dpop+jwt`), verify with the
  embedded `jwk`, check `htm`/`htu`/`iat`, record `jti` in Redis for the acceptance window, return
  the thumbprint. `DPoP-Nonce` (RFC 9449 §8) is optional; recommended off at first to keep the
  service provider's implementation simple.
- `app/forms/openid_connect_introspect_form.rb#response`: merge `cnf: { jkt: }` when bound.
- `app/presenters/openid_connect_configuration_presenter.rb`: add `dpop_signing_alg_values_supported`
  inside `delegation_configuration`.
- Migration: `add_column :token_exchange_resource_servers, :dpop_required, :boolean, default: false, comment: 'sensitive=false'`
  (`dpop_jkt` already exists on the token tables).
- `lib/identity_config.rb`: no new key needed; the per-resource-server flag is the control.
- Reference apps (§14): service provider gains `lib/dpop.rb` (ES256 key at boot; proofs with
  `htm`, `htu`, `iat`, `jti`, `ath`) and sends `Authorization: DPoP <token>` plus a `DPoP` header;
  resource server gains a `Dpop.verify` step in `#authorize!` after the scope check:

  ```ruby
  if @introspection['cnf']                                           # RFC 9449 §4.3, §7.1
    halt 401, www_authenticate('DPoP', error: 'invalid_dpop_proof') unless
      Dpop.verify(request.env['HTTP_DPOP'], method: request.request_method, url: request.url,
                  access_token: token, expected_jkt: @introspection['cnf']['jkt'])
  end
  ```

  Add harness scenario "DPoP on: call without proof → 401 `invalid_dpop_proof`; with proof →
  200", and run the reference apps with DPoP **on** by default so partners copy the secure path.
- §11 threat table: "Stolen delegated token used at the right API" → control becomes
  "DPoP binding; 15-minute life".

**Standards:** RFC 9449 (DPoP); RFC 7800 (`cnf` claim); RFC 9700 §4.10.1 (sender-constraining
recommendation); RFC 8705 (mTLS alternative).

---

## Appendix D — Repository mapping and implementation order

### D.1 Repositories

Four repositories implement this document. Each is a copy of an existing Login.gov repository
(baseline commits as in §0 and §14.3), with the changes below layered on top.

| Repository | Role | Starts from |
|---|---|---|
| `identity-idp` | The identity provider: everything Login.gov itself builds. | `18F/identity-idp` `48a1ff3e3f` |
| `identity-sts-sinatra` | The **service provider** reference (§14.3): signs the user in, requests delegation, exchanges, refreshes, revokes, and calls the two resource servers. | `identity-oidc-sinatra` `907fc7f` |
| `identity-oidc-sinatra` | The **OIDC-consuming agency resource server** reference (§14.4): accepts delegated OAuth tokens, introspects, enforces scope, runs the agency-role Attempts viewer. | `identity-oidc-sinatra` `907fc7f` |
| `identity-saml-sinatra` | The **SAML-consuming agency resource server** reference (§15.7): accepts delegated SAML assertions, validates locally, enforces `delegation_scopes`, runs the agency-role Attempts viewer. | `identity-saml-sinatra` `f337f22` |

The two agency apps also play the agency's own sign-in application, which is what §16 (third-party-initiated login) exercises.

**Amended 2026-10-09 (D57, D58).** `identity-sts-sinatra` no longer starts from `identity-oidc-sinatra` `907fc7f`: its `main` is rewritten as a browser public client (static files plus a non-secret JSON configuration; PKCE, WebCrypto DPoP key in IndexedDB, every call from the browser) and the earlier history, which committed a demo private key, is not carried over. In D.2 its §5 entry reads "performs the exchange from the browser with a DPoP proof, `resource`, `requested_token_type`" and its Appendix C entry "DPoP proof generation in the browser, one non-extractable key per sign-in"; the §8 entry of `identity-saml-sinatra` (agency-role Attempts viewer) is withdrawn, as is step 20 in D.4, and step 13 reads "tokens in page memory" in place of "server-side token storage". `identity-oidc-sinatra` keeps its viewer (step 18).

### D.2 Section-to-repository mapping

"Primary" means the bulk of that section's code lands in the repository. "Consumer" means the
repository has to honor the behavior but writes little of it.

**`identity-idp`** (identity provider)

- §1, §2 — context, no code.
- §3 — primary. Onboarding data model: new `service_providers` columns, `token_exchange_resource_servers`, `token_exchange_scopes`, localdev fixtures.
- §4 — primary. Consent scopes, CON-1..16, ACC-1..3, Account → Delegated access page.
- §5 — primary. Token exchange on the token endpoint, `token_exchange_tokens`, discovery document (DISC-1..5).
- §6 — primary. Introspection endpoint (INT-1..8).
- §7 — primary. Refresh, rotation, reuse detection, revocation (REF-1..9).
- §8 — primary. Attempts events with `delegation_id`, delivery to target agencies (ATT-1..10).
- §9 — primary, IdP only. Billing rows and `request_id` convention (BIL-1..8).
- §10 — primary. Feature flags and config.
- §11 — shared. Threat controls implemented mostly here.
- §12 — shared. IdP unit, integration and feature specs.
- §13 — primary. Rollout flags and sequencing.
- §14 — §14.5 only (local IdP fixtures in `config/service_providers.localdev.yml`).
- §15 — primary. SAML assertions as issued token type (SAML-1..9, `saml_idp` gem change, `DelegatedSamlAssertion`).
- Appendix C — primary (built).

**`identity-sts-sinatra`** (third-party service provider)

- §4 — consumer. Requests `token_exchange:*` scopes, reads `scope` from the token response, shows approved vs. declined (CON-4, CON-15).
- §5 — consumer. Performs the exchange server-side with `private_key_jwt`, `resource`, `requested_token_type` for both JWT and SAML (§5.3 checklist).
- §7 — consumer. Refresh on a timer with rotation, revoke on demand, re-consent on `consent_required`.
- §14 — primary for REF-IMPL-1, 4, 5, 6, 7 and §14.3, §14.6 (end-to-end harness and compose file), §14.7 partner guide.
- §15 — consumer. Requests `urn:ietf:params:oauth:token-type:saml2`, base64url-decodes and posts the assertion to the SAML agency; no SAML validation of its own.
- Appendix C — consumer (built). DPoP proof generation, one key per signed-in session.
- §16 — primary for the initiator side (TPL-1, TPL-2, TPL-7).

**`identity-oidc-sinatra`** (OIDC-consuming agency resource server)

- §6 — primary on the consumer side. Introspects with its own `private_key_jwt` assertion, checks `active`, `aud`/resource, `scope` per route, `act`, `delegation_id` (§6.3 checklist).
- §7 — consumer. Treats `active: false` as revoked; no refresh logic.
- §8 — primary on the consumer side. Attempts API viewer in the agency role, joins events to API calls on `delegation_id` (REF-IMPL-3).
- §14 — primary for REF-IMPL-2, 3, 4, 7 and §14.4 (`/records` routes, decision log), participant in §14.6 harness.
- §11 — consumer. Bearer token handling, no logging of tokens.
- Appendix C — consumer (built). DPoP proof verification when the token is bound.
- §16 — primary for the relying-party side (TPL-3..7) on the agency's OIDC sign-in app.

**`identity-saml-sinatra`** (SAML-consuming agency resource server)

- §15 — primary on the consumer side. Accepts a bearer assertion, validates signature, `Audience`, `Conditions` and the five-minute `SubjectConfirmationData` window with `ruby-saml`, reads `delegation_scopes`, `delegation_id` and `actor` attributes, enforces scope per route (§15.7). No introspection.
- §7 — consumer. Revocation observed only at the next refresh; nothing to build beyond honoring assertion windows.
- §8 — consumer. Same agency-role Attempts viewer as the OIDC agency, joined on `delegation_id` from the assertion attribute.
- §14 — participant. Runs in the same one-command local setup and end-to-end harness (REF-IMPL-4, 5) as the SAML target.
- §11 — consumer. Assertion handling and replay protection.
- §16 — primary for the relying-party side (TPL-3..7) on the agency's SAML sign-in app.

Not mapped to any repository: §9 outside the IdP, §13 rollout, Appendix A open decisions, and the
onboarding forms. Those are process items.

### D.3 Dependency chain

Arrows read "depends on". A section may start once everything to its right exists in the same
repository or is stable enough to code against (a table, a response shape, an endpoint).

```
§10 config keys ─────────────────────────────────────────────┐
§3  data model (SPs, resource servers, scopes) ◄── nothing   │
 ▲                                                           │
 ├── §4  consent: scope parsing, screen, grants, token       │
 │      response `scope`, account page                       │
 │       ▲                                                   │
 │       ├── §5  exchange ◄── §7.2 refresh table (EXC-7 needs `refresh_token`) ◄── §10
 │       │        ▲
 │       │        ├── §6  introspection (reads token_exchange_tokens; shares the
 │       │        │       RFC 7523 authenticator with §5/§7)
 │       │        ├── §7  refresh, rotation, reuse detection, revocation endpoint
 │       │        ├── §9  billing (row per exchange; SpReturnLogWriter extract can go first)
 │       │        ├── §15 SAML issued type ◄── §7 (family remembers type), saml_idp gem change
 │       │        └── Appendix C DPoP (optional) ◄── §6
 │       └── §8  Attempts: buffer at authorize (§4.2), release at consent (§4.4/§4.5),
 │              token/refresh/revoke events (§5, §7)
 └── §14.5 localdev fixtures ◄── §3 seeder changes
§14 reference apps and harness ◄── §4, §5, §6, §7, §8 (OIDC path); §15 (SAML path)
§11 security summary, §12 tests ── cross-cutting, verified as each section lands
§13 rollout ◄── everything above
```

Three couplings are not obvious from the section order:

1. **§5 and §7 ship together.** EXC-7/REF-1 make `refresh_token` part of the exchange response, so
   the refresh-token table and `TokenExchangeRefreshToken.issue_for` must exist before the exchange
   form is complete. The refresh *grant* and revocation endpoint can land in the same change or
   immediately after.
2. **§6, §5 and §7 share one client authenticator.** `ResourceServerAuthenticator` (§6.2) is the
   RFC 7523 check parameterized by key source. Build it once, first, and have the exchange,
   refresh, revocation and introspection forms all call it.
3. **§8 straddles §4 and §5.** The buffer and the delegation context are set at authorize (§4.2),
   the release runs at consent (§4.4/§4.5), and the token events fire from the exchange and refresh
   forms (§5/§7). It cannot be finished until §7 exists, but the consent-side half can be built
   with §4.

### D.4 Implementation order

The order below satisfies every dependency in D.3 and keeps each step independently testable and
committable. Steps inside a repository are sequential; repositories after step 8 can proceed in
parallel once the IdP endpoints they call exist.

**`identity-idp`**

| Step | Sections | Deliverable | Depends on |
|---|---|---|---|
| 1 | §10, §3, §4.5, §5.2, §7.2, §15 (`token_format`), §9.3 (`sp_return_logs` columns) | All migrations, models, `IdentityConfig` keys, seeder/updater changes, `sensitive=` comments. Feature flag off. | — |
| 2 | §4.1–§4.2 | `token_exchange:` scope parsing (CON-1..4), `requested_delegation_scopes` in the SP session, `invalid_scope` on the authorize endpoint. | 1 |
| 3 | §4.3–§4.6 | Consent screen changes (CON-5..9a), grant writing (CON-10..14), `scope` in the token response (CON-15/16), `RevokeServiceProviderConsent` cascade. | 2 |
| 4 | §4.7 | Account → Delegated access page (ACC-1..3). | 3 |
| 5 | §6.2 (authenticator only) | `ResourceServerAuthenticator`: RFC 7523 + RFC 8725 checks, `jti` replay cache, parameterized key source. | 1 |
| 6 | §5, §7, §5.4 | Exchange form, refresh form, revocation endpoint, `TokenController#build_form` dispatch, rate limits, discovery metadata. | 3, 5 |
| 7 | §6 | Introspection endpoint (INT-1..8), `AccessTokenVerifier` fixes. | 6 |
| 8 | §9 | `Billing::SpReturnLogWriter` extract, delegated rows at exchange, report review (BIL-6), `DelegationOutcomesReport`. | 6 |
| 9 | §8 | Attempts buffer, delegation context, `DelegatedRelease`, token/refresh/revoke events, schema docs. | 3, 6 |
| 10 | §15 | `saml_idp` gem change, `DelegatedSamlAssertion`, `requested_token_type` branch, refresh for SAML families, revoke by assertion ID. | 6, 7 |
| 11 | §14.5 | Localdev fixtures for the three reference apps. | 1 |
| 12 | §11, §12, §13 | Test sweep against the threat table, rollout notes. | all |

**`identity-sts-sinatra`** (service provider) — after IdP step 6 (OAuth) and step 10 (SAML)

| Step | Sections | Deliverable |
|---|---|---|
| 13 | §14.3 authorize / token response | Delegation scope checkboxes, approved-vs-declined display, server-side token storage. |
| 14 | §14.3 exchange / call / refresh / revoke | `exchange`, `refresh`, `revoke`, `/delegated/*` routes and view, reuse-detection demo. |
| 15 | §15 consumer | "Request SAML" toggle; post the assertion to the SAML resource server. |
| 16 | §14.6, §14.7 | Compose file, end-to-end scenarios, partner guide. |

**`identity-oidc-sinatra`** (OIDC resource server) — after IdP step 7

| Step | Sections | Deliverable |
|---|---|---|
| 17 | §14.4 | `authorize!`, `introspect`, cache within INT-8, `/records` GET and POST with different scopes, decision log, fail closed. |
| 18 | §8.5, REF-IMPL-3 | Agency-role Attempts viewer with the "Delegated sessions" join on `delegation_id`. |

**`identity-saml-sinatra`** (SAML resource server) — after IdP step 10

| Step | Sections | Deliverable |
|---|---|---|
| 19 | §15.7 | Bearer-assertion endpoint: `ruby-saml` validation against IdP metadata, `Audience`, `Recipient`, five-minute subject-confirmation window, `delegation_scopes` per route, `actor` read and logged. |
| 20 | §8.5 | Same agency-role Attempts viewer, joined on the `delegation_id` attribute. |

### D.5 Implementation notes (as built, 2026-09-28)

- Scope strings on the wire always carry the `token_exchange:` prefix (authorize request, token response
  `scope`, exchange response, introspection `scope`, SAML `delegation_scopes`). Resource servers compare
  full strings.
- The consent screen loads the requested scopes, their resource servers and the agency SPs with one
  query per table and joins them in memory; the account page does the same.
- Code comments describe requirements functionally and cite RFC sections; they do not cite this
  document's requirement IDs, because developers reading the repositories will not have it.
- Generated certificates and keys for the local reference apps are never committed; each developer
  generates the OIDC resource server key pair (`make rs_keypair` in `identity-oidc-sinatra`) and copies
  the certificate into `identity-idp/certs/sp/rs_records_demo.crt` (ignored there). The reference
  resource server's spec helper and `make setup` generate the pair when it is missing so a fresh clone
  and CI work. When a key pair had already been committed, the unpushed history was rebuilt commit by
  commit with `git commit-tree` (same trees minus the two files) rather than `git filter-branch`.
- The IdP's local `config/application.yml` (ignored) enables the Attempts API and lists the two agency
  issuers in `allowed_attempts_providers` with scrypt-hashed poll tokens for the contract's placeholder
  secrets; `bin/rake dev:prime` provides the identity-verified user `test2@test.com`. The stored token
  `value` is the **digest portion** of the scrypt hash (`SCrypt::Password.new(hash).digest`), not the full
  `SCrypt::Engine.hash_secret` string — `Api::RequestTokenValidator` compares digests; the full string
  yields a 401 on every poll.
- Local reference-app ports: service provider 9292, OIDC resource server 9393, SAML resource server
  4567; each loads its `.env` (copied from `.env.example`).

Step 1 is the only step every other step waits on. Steps 2–4 (consent) and step 5 (authenticator)
are independent of each other and can proceed in parallel. Steps 7, 8 and 9 are independent of each
other once step 6 exists. Steps 13–20 are independent across repositories.

---

## Appendix E — Protocol-level decisions made during implementation

Each row is a choice made where OAuth 2.0 / RFC 8693 / SAML 2.0 leave latitude, or where this design
departs from the letter of a specification. "Status" says whether the owner has confirmed the choice or
should revisit it. New rows are added as they arise; questions are also raised in conversation at the
time they come up.

| # | Decision | Specification basis | Alternatives considered | Status |
|---|---|---|---|---|
| E1 | Scope strings carry the `token_exchange:` prefix everywhere on the wire, including introspection `scope` and the SAML `delegation_scopes` attribute. | RFC 6749 §3.3 treats scope as opaque strings; RFC 8693 returns `scope` as granted. | Bare values (`records_read`) in tokens and assertions. | Confirmed (local contract) |
| E2 | Exchange requires the service provider's Login.gov sign-in session to still be live (EXC-12); once minted, the family is session-independent. | RFC 8693 is silent on subject-token freshness. | Accept any unrevoked subject token, relying on the grant alone. | Confirmed 2026-10-09 (E64) |
| E3 | Exchange accepts an optional `scope` that narrows to a subset of approved values; values outside the approved set fail with `invalid_scope` (EXC-13). | RFC 8693 §2.1 `scope` OPTIONAL; RFC 6749 §5.2 `invalid_scope`. | Ignore `scope`; or reject any `scope` parameter. | Confirmed |
| E4 | All approved scopes of one resource are exchanged into one token; the earliest grant's `delegation_id` identifies the exchange (EXC-14). | Design rule "one token per API" (EXC-4). | One token per scope; a new delegation id per exchange. | Confirmed |
| E5 | A service provider not approved for delegation fails with `invalid_client`; a rate-limited token-endpoint call fails HTTP 400 `invalid_request`; a rate-limited introspection call fails HTTP 429 `invalid_request` (EXC-15, INT-9). | RFC 6749 §5.2 defines the token-endpoint error set (no 429); RFC 7662 leaves introspection errors to RFC 6749 §5.2 / HTTP; RFC 6585 defines 429. | HTTP 429 at the token endpoint too (common in practice, outside RFC 6749); `invalid_grant` for the unapproved SP. | Superseded 2026-10-09 (E73): no hard rate limits, so neither error is produced; `invalid_client` for the unapproved SP stands. |
| E6 | The token response adds `refresh_token_expires_in` (EXC-16) and, for SAML/identifiers-only cases, `attributes: "identifiers_only"` (SAML-5b, INT-10). | RFC 6749 §5.1 allows additional response parameters; neither member is standardized. | Omit and let the SP infer from `expires_in`/absent claims. | **Revisit:** keep both non-standard members? |
| E7 | Refresh refuses a `resource` parameter with `invalid_request` (REF-11). | RFC 8707 §2.2 *permits* `resource` on refresh to down-scope the audience. | Accept `resource` only if it equals the family's resource; support audience narrowing. | **Revisit** |
| E8 | Refresh tokens rotate on every use; a replayed (already-rotated) token revokes the whole family (REF-4/REF-10). | RFC 9700 §4.14.2 (recommended for public clients; here applied to confidential clients too). | No rotation for confidential clients (RFC 9700 allows client authentication alone). | Confirmed |
| E9 | Client assertions require `exp` (≤ 5 min after `iat`) **and** `jti`, replay-checked, at every delegated-access endpoint; the existing authorization-code grant keeps its looser check. | RFC 7523 §3: `exp` required, `jti` optional; RFC 8725 hardening. | Same strictness at `/token` for authorization_code (would affect existing SPs). | Confirmed; back-porting to authorization_code is a separate decision. |
| E10 | Introspection answers 401 `invalid_client` for unknown or failed callers and exactly `{"active": false}` for everything else (INT-1, INT-3). | RFC 7662 §2.1 requires caller authentication; §2.2 permits `active: false` with no reason. | 400/403 for unknown callers. | Confirmed |
| E11 | Introspection returns userinfo-shaped identity claims for the agency SP's attribute bundle (INT-10) rather than opening `userinfo` to delegated tokens. | RFC 7662 §2.2 allows extension members; OIDC Core §5.3 `userinfo` is the client's endpoint and is unauthenticated. | `userinfo` with the resource server's client assertion; introspection with `sub` only. | Confirmed 2026-09-29 |
| E12 | `act` is `{ "sub": <service provider issuer> }`; no nesting, since chained delegation is a non-goal. Introspection also returns `token_type: "Bearer"`. | RFC 8693 §4.1 (`act.sub`); RFC 7662 §2.2 (`token_type` optional). | Include `act.client_id`; omit `token_type`. | Confirmed |
| E13 | Discovery advertises `introspection_endpoint`/`revocation_endpoint` and the new grant types only while the feature is on; no `token_exchange_endpoint`; `token_exchange:*` values are not enumerated in `scopes_supported`. | RFC 8414 §2 metadata names; RFC 8693 §2.1 (exchange at the token endpoint). | A custom metadata key; enumerating partner scopes. | Confirmed |
| E14 | Revocation accepts an access token, a refresh token, or (for SAML families) the assertion `ID` in the `token` parameter, and always answers `200 {}` once the caller authenticates. | RFC 7009 §2.1 (`token` is the token; `token_type_hint` optional); §2.2 (200 for unknown tokens). | Require the full encoded assertion for SAML revocation. | **Revisit:** accepting the bare assertion ID is a Login.gov extension. |
| E15 | SAML token = the bare `<saml:Assertion>` (or `<saml:EncryptedAssertion>`), base64url without padding, returned in `access_token` with `token_type: N_A`. | RFC 8693 §3 (`saml2` token type), §2.2.1 (`N_A`). | Wrap in `<samlp:Response>`. | Confirmed |
| E16 | Bearer `SubjectConfirmationData/@Recipient` = the resource server **identifier** (a URI, not an HTTP endpoint the assertion is POSTed to); `Audience` = the same identifier; no `InResponseTo`. | SAML Core §2.4.1.2 (`Recipient` is a URI); SAML Profiles §4.1.4.2 requires `Recipient` to be the ACS URL for the **Web Browser SSO** profile, which does not apply to an RFC 8693-delivered assertion. | Use the API's base URL as `Recipient`; omit `Recipient`. | **Revisit:** confirm agencies' validators accept a non-URL `Recipient`. |
| E17 | `actor`, `delegation_scopes`, `delegation_id` are plain attributes (URI name format, `Name` = friendly name); no Delegation Restriction condition; no additional Condition types. | SAML Core §2.5.1 (unknown Condition ⇒ Invalid); OASIS Delegation Restriction considered and rejected. | Delegation Restriction condition (fail-closed). | Confirmed |
| E18 | Assertion `Conditions` lifetime one hour; `SubjectConfirmationData/@NotOnOrAfter` five minutes; no introspection required of SAML consumers; revocation takes effect at the next refresh (SAML-4, SAML-9, 15.5). | SAML Core §2.5.1.2, §2.4.1.2. | Short `Conditions` (5 min); introspection by assertion ID. | Confirmed |
| E19 | Whether a bearer assertion is single-use (replay-protected) or reusable within its window is the **agency's** declared choice; service providers default to single-use and refresh per call (SAML-10). | SAML Profiles §4.1.4.5 (replay protection for bearer assertions). | Mandate one behavior for all agencies. | **Revisit:** default and onboarding-form question. |
| E20 | The `saml_idp` gem behavior change (omit `InResponseTo` when there is no request; caller-supplied subject-confirmation window) is applied as a prepended module inside `identity-idp` until it can be upstreamed and retagged. | Implementation packaging; no protocol effect. | Fork and retag the gem now. | Confirmed for now |
| E21 | Unknown `token_exchange:*` values at authorize fail with `invalid_scope`; unknown unprefixed values keep today's silent-ignore behavior (CON-2, CON-3). | RFC 6749 §4.1.2.1 (`invalid_scope`) vs. Login.gov's existing tolerance. | Reject all unknown scopes (would break existing SPs). | Confirmed |
| E22 | Rate limits are keyed per authenticated client (SP issuer / resource server identifier), not per IP (EXC-8, INT-7). | RFC 6749 §10 general guidance; no normative rule. | Per-IP limits (would starve busy agency gateways). | Superseded 2026-10-09 (E73): no rate limits; monitoring is keyed per authenticated client the same way. |
| E24 | Claim formats follow each protocol's own convention: introspection uses userinfo formats (`verified_at` epoch integer, `birthdate` ISO date, `phone` E.164, composite `address`), the SAML assertion uses the existing SAML attribute formats (ISO 8601 `verified_at`, separate address attributes). | OIDC Core §5.1 standard claims; existing Login.gov SAML attribute conventions. | One canonical format for both. | Confirmed (agencies already parse each format) |
| E25 | The `email` claim released to an agency for a delegated token is the address the user chose to share with the **service provider**; a delegated-only user has no per-agency email choice. | OIDC Core §5.1 (`email`); Login.gov's per-SP email selection. | Ask the user to pick an email per agency on the consent screen; release the account's primary email. | **Revisit:** acceptable to agencies? |
| E27 | "Consent already given for this authorization" is keyed on a digest of the authorize URL, not on the IdP's SP request id, because the request id is reused across authorizations of one SP within a browser session while the URL (fresh `state`/`nonce`) is not. | OIDC Core §3.1.2.1 (`state`, `nonce` per request) | Key on request id (skipped the screen when a scope was added); key on the requested scope set (would suppress a legitimate re-ask for the same set). | Confirmed 2026-09-29 |
| E26 | An exchange for a resource the user has not delegated (no live grant for any of its scopes) fails with `invalid_target`, not `invalid_grant`: the subject token is valid, but Login.gov is "unable to issue a token for the target service indicated by resource". `invalid_grant` is reserved for a bad, foreign, expired or session-less subject token. The first implementation returned `invalid_grant` here and was corrected after the live run exposed the inconsistency with EXC-3. | RFC 8693 §2.2.2 | `invalid_grant` for every consent problem. | Confirmed 2026-09-29 |
| E23 | Sender-constrained tokens (DPoP, RFC 9449) are adopted: Login.gov binds at exchange and refresh when a proof is present, agencies require it per resource server (`dpop_required`). Amended 2026-10-09: the per-resource-server flag is removed, binding follows the client type (E82). | RFC 9700 §4.10.1 (SHOULD sender-constrain); RFC 9449 §5. | Defer; mandate globally (option C). | Confirmed 2026-10-08 |
| E28 | `DPoP-Nonce` (RFC 9449 §8) is not issued; freshness relies on `iat` within 60 s past / 10 s future and single-use `jti` kept in Redis for that window. **Amended 2026-10-10.** As built the window is `dpop_proof_max_age_seconds` (±300 s) and the `jti` is kept for twice the window (E98). | RFC 9449 §4.3 item 10 (nonce is optional), §11.1. | Server-provided nonce (extra round trip through the service provider's relay). | **Revisit** if clock skew at partners causes rejections |
| E29 | A proof on the refresh of an unbound family binds the refreshed access token to the proof key; the earlier bearer token keeps working until expiry. A bound family refuses a refresh without a proof from the same key. | RFC 9449 §5 (the issued token is bound to the proof key; refresh tokens of confidential clients are not themselves bound). | Refuse proofs on unbound families; ignore them. | Confirmed 2026-10-08 |
| E30 | A key-bound SAML assertion carries the thumbprint as a plain `dpop_jkt` attribute; the SAML resource server computes `ath` over the base64url assertion exactly as presented in the Authorization header. | RFC 9449 is OAuth-specific; SAML Holder-of-Key subject confirmation would need a certificate, not a JWK. | Holder-of-Key SubjectConfirmation; no binding for SAML. | **Revisit:** confirm with the first SAML agency |
| E32 | Introspection carries `iss`, a per-token `jti` (SHA-256 of a fixed prefix and the stored digest; never the digest or the row id) and `auth_time` (the service provider identity's `last_authenticated_at`), so the response has every element NIST IR 8587 §5.2.1.1 lists; `auth_time` was previously excluded as session-bound. | RFC 7662 §2.2 (`iss`, `jti` optional members); NIST IR 8587 §5.2.1.1. | Omit them (prior design); use the row id as `jti`. | Confirmed 2026-10-08 |
| E33 | Third-party-initiated login in the reference apps uses the plain OpenID Connect Core §4 parameters (`iss`, `login_hint` as a single-use server-side correlation UUID, `target_link_uri` against an exact-origin allow-list) with no signed hand-off; the agency returns `login_hint`, its own `iss`, and `status`. Applied unchanged to the SAML agency. | OpenID Connect Core 1.0 §4. | Signed hand-off JWT (functional requirements Appendix C); no return to the initiator. | Confirmed 2026-10-08; signed hand-off remains a production option |
| E35 | A delegating service provider's sign-in row is billable at handoff and waived (set non-billable, `access_type` `delegating_sign_in`) by the first exchange for that connection, found by `sp_return_logs.identity_id` as the most recent billable direct row. Alternatives: never bill the SP (would leave sign-ins with no token unpaid), or bill both (double charge). | Login.gov billing is per unique user per agreement per month over `sp_return_logs`; no standard applies. | Flag at handoff instead of at exchange (impossible: the exchange comes later); link via the SP request id (not stored on the identity). | Confirmed 2026-10-08 |
| E36 | The partner report's per-user key excludes `access_type` and `delegated_proofing`; they are tallied alongside. The earlier design (BIL-11 as first written) double-counted a user who arrived both directly and by delegation in a month and made them "new" again the next month. | Invoice semantics: one billed user per agency per month. | Keep on key and dedupe in the supplement (never built). | Confirmed 2026-10-08 |
| E34 | A SAML agency completes a third-party hand-off from a page of its own rather than a redirect from its assertion consumer, because Chrome enforces the IdP's `form-action` CSP on redirects that follow the SAML POST binding (found in the live harness: the browser stayed on `/api/saml/finalauthpost` with the 303 never followed). An OIDC agency's callback is reached by a GET redirect and is not affected. | CSP Level 3 `form-action` (applies to form submission and, in Chromium, to its redirects); SAML Bindings §3.5 (HTTP POST). | Relax `form-action` on Login.gov's POST page to include third-party return origins (would require Login.gov to know every initiator). | Confirmed 2026-10-08 |
| E31 | `dpop_jkt` on a token never changes: `mint_from_family!` copies the family's thumbprint unless a verified proof supplied one, so a bound family cannot emit an unbound token. | RFC 9449 §5. | Allow unbinding at refresh. | Confirmed 2026-10-08 |
| E37 | The unit of consent is the **application** (an agency-owned SP record owning one or more resource servers), not the agency and not the individual API. One scope per application: `token_exchange:<delegation_scope_value>`. | OIDC Core §3.1.2.1 (`scope` values are opaque strings defined by the provider); RFC 8707 (`resource` still selects one URL at exchange). | Agency-level consent (fewer, coarser choices); per-API scopes (the first implementation). | Decided 2026-10-09 |
| E38 | Requested applications are **take-it-or-cancel**: rendered checked and disabled; cancelling the screen is the only way to decline, as for requested attributes today. No per-application decline is recorded. | OIDC Core §3.1.2.4 (`access_denied` on user denial applies to the whole request). | Optional per-application checkboxes with partial approval (first implementation and FR-CUX-5 as first written). | Decided 2026-10-09 |
| E39 | The remember choice stays for the consent screen (unchecked, 12 months); approvals made in advance from the account page are always remembered for 12 months from the moment given. | No protocol constraint; Login.gov consent expiry conventions. | Always remember; never remember. | Decided 2026-10-09 |
| E40 | Grants are keyed by (user, service provider issuer, application), not by the service provider's `identities` row, so advance approval can exist before any authorization. | RFC 6749 §1.1 roles (resource owner authorizes the client independently of a session). | Key on identity (first implementation); separate pre-approval table. | Decided 2026-10-09 |
| E41 | The account page lists every active application that accepts the service provider (registry-defined reach), grouped by agency, for service providers the user has connected to; applications under never-connected service providers are deferred. | — | Only applications the user has connected to (`sbx-taigrr`); connected plus previously requested. | Decided 2026-10-09; never-connected case open |
| E42 | Only content changes the editor marks **material** invalidate remembered grants; two version counters per content owner (`*_content_version`, `*_material_version`). | — | Every edit re-asks (first implementation); never re-ask. | Decided 2026-10-09 |
| E43 | Consent content for agencies, applications and service providers is edited in the partner Dashboard and synced by `ServiceProviderUpdater`; production through the seeder. Dashboard fields are a dependency on `identity-dashboard`, stated in code comments. A branch seed file and env-guarded rake task cover non-production until then. | — | IdP admin page; YAML in the config repository only. | Decided 2026-10-09 |
| E44 | Agency-level consent content lives on `agencies` (description, learn-more URL, version pair) alongside the existing name and logo. | — | Repeat agency text on each application. | Decided 2026-10-09 |
| E45 | No application-configuration allow-list of service providers (`token_exchange_service_providers`, inherited from `sbx-taigrr`): approval is `token_exchange_enabled_sp` on the SP record; `token_exchange_enabled` is the only configuration switch. Nothing from `sbx-taigrr` is kept for compatibility; its grant tables and opt-in column are dropped and recreated in the new shape. | ONB-5 (SP configuration is the reviewed path). | Keep the config key as a sandbox convenience; rename old tables to `legacy_*`. | Decided 2026-10-09 |
| E46 | Configuration keys (§10) are introduced by the feature that reads them (exchange TTL and rate limit with §5, refresh with §7, introspection cache and rate limit with §6, report recipients with §9), not all at once in the onboarding feature, so no key exists that nothing reads. | Operational hygiene; `config/initializers/unused_identity_config_keys.rb` reports unused keys. | Add every key in the first feature (first implementation). | Decided 2026-10-09 |
| E47 | Code comments describe current behavior only: no design history and no references to features that will replace or widen the code. That context lives in the implementation plan and commit messages. External dependencies that exist today (the Dashboard lacks the fields; the seed task fills in) are stated in comments. | Reviewer and developer feedback: comments are read against the code, not the history. | Comments carrying "previous design" and "feature X replaces this" notes (first drafts). | Decided 2026-10-09 |
| E48 | Cancel on the consent screen returns the person to the service provider with `error=access_denied` (OIDC Core §3.1.2.6) through the completions screen's existing cancel path; no sign-in completes. | OIDC Core §3.1.2.6 (`access_denied`). | Stay signed in on a Login.gov page; allow unchecking instead. | Decided 2026-10-09 |
| E49 | `token_exchange:*` values on a request that does not ask for identity verification fail with `invalid_scope`. | RFC 6749 §4.1.2.1 (`invalid_scope`: requested scope is invalid, unknown, or malformed). | Drop the values and continue as IAL1. | Decided 2026-10-09 |
| E50 | Only OpenID Connect service providers can request delegation; SAML stays a token format issued to agency APIs. | OIDC Core §3.1.2.1 (`scope`); no SAML counterpart in the reference applications. | Carry delegation on a SAML AuthnRequest extension. | Decided 2026-10-09 |
| E51 | The remember choice on the consent screen never shortens an existing remembered approval; it applies to requested applications that lack one. | Consent stability for the person. | Re-record every requested application with the screen's choice. | Decided 2026-10-09 |
| E52 | Rows are badged `new`, `already approved` or `updated`; a stale approval is shown locked with today's content and re-recorded on approval. No content history table; grants keep version numbers only. | — | History table of content versions (deferred). | Decided 2026-10-09 |
| E53 | The service provider is a **public client** (PKCE, no `private_key_jwt`); all of its tokens (own access token, delegated tokens, refresh tokens) are DPoP-bound and Login.gov verifies the proof at the code exchange, the token exchange, refresh and userinfo. Confidential clients are unchanged. Replaces the confidential-client baseline recorded earlier on 2026-10-09. | RFC 9449 §5, §7; RFC 9700 §2.2.2, §4.10.1; OAuth 2.0 for Browser-Based Apps (BCP draft). | Confidential client with `private_key_jwt` (withdrawn); bearer tokens for a public client. | Decided 2026-10-09 |
| E54 | DPoP is mandatory for every public client approved for delegation, as a property of the service provider record, not per request. | RFC 9449 §5 (`dpop_bound_access_tokens` client metadata). | Optional per request. | Decided 2026-10-09 |
| E55 | The authorization code is bound to the DPoP key with the `dpop_jkt` authorize parameter for public clients. | RFC 9449 §10. | Rely on PKCE alone. | Decided 2026-10-09 |
| E56 | Delegated tokens are refused at userinfo even with a valid proof; agency attributes are available only through introspection, which the agency authenticates to and after which the agency verifies the proof on the API call. | RFC 7662; RFC 9449 §7. | Allow a bound delegated token at userinfo. | Decided 2026-10-09 |
| E57 | Server nonces (RFC 9449 §8) remain deferred for the public-client baseline. The threat a nonce addresses is a proof that is created ahead of time or captured and replayed within its validity window. The controls already in place bound that window tightly: a proof is accepted only if its `iat` is within 60 seconds past or 10 seconds future, its `jti` has not been seen at Login.gov in that window (single-use, kept in Redis), its `htm` and `htu` match the request, and its `ath` matches the token it accompanies; agencies apply the same checks on API calls. A captured proof is therefore usable only for the same method and URL, with the same token, within a minute, and only once at Login.gov. What remains is a proof pre-computed by code running in the service provider's page for a future request to a known URL; a server nonce would force that code to fetch a fresh nonce first, which it could also do if it controls the page, so the nonce raises the bar without closing the case. Against that, a nonce costs an extra round trip on every first request (`use_dpop_nonce`), nonce state and rotation at Login.gov and at every agency, and a second failure mode for partners to handle. Decision: defer; keep the 60-second window and single-use `jti`. Revisit if a partner's clock skew makes the window too tight, if a deployment shows pre-computed proofs in the wild, or if an agency asks for nonces on its API. **Amended 2026-10-10.** The window as built is `dpop_proof_max_age_seconds` either side of now (±300 s, configurable), with the `jti` kept for twice the window; the reasoning and the deferral stand (E98). | RFC 9449 §8, §11.1. | Issue `DPoP-Nonce` from the token endpoint and the agencies. | Decided 2026-10-09 (deferred); revisit on the triggers listed |
| E58 | The account page lists service providers the person has never connected to. | Nothing in the grant model depends on an identity row (CON-10 as amended); a person who knows they will use a service can approve before the first sign-in, which the consent screen then honors (ACC-4). | List connected service providers only (earlier 5.3 finding). | Decided 2026-10-09 |
| E59 | Advance approval is two-step: select applications, then confirm on a page that shows the consent-screen content. | FR-CUX-13 requires the same disclosure as the consent screen; a server-rendered page carries the full agency content, works without JavaScript and lets several applications be approved under one disclosure. | A per-row toggle with a JavaScript modal (5.1's inline control). | Decided 2026-10-09 |
| E60 | Every revocation, single or whole service provider, has its own confirmation page. | Revocation ends access that other systems may be relying on mid-task; the product owner chose consistency with disconnecting a service over a one-click undo-able action. | Immediate single-application revocation. | Decided 2026-10-09 |
| E61 | Approvals and revocations from the account page are recorded in account history and emailed. | They change what a third party may do with the person's identity; the person should be able to notice and disavow them like a connection change (`sp_user_consent_granted`/`revoked`). | Analytics only. | Decided 2026-10-09 |
| E62 | Token storage is hybrid: live access tokens and SAML assertions are Redis entries keyed by SHA-256 digest with a TTL equal to the lifetime, indexed per grant and per refresh family for cascading revocation; refresh tokens (digest-only, rotating) and a secret-free issuance record live in Postgres (§5.2, §7.5, §7.6 as amended). | RFC 6749 §10.3 (tokens confidential at rest); RFC 9700 §4.14. Short-lived tokens expire on their own and introspection is a hot lookup; refresh families and reporting need durability. | Postgres-only (table growth, purge jobs); Redis-only (no durable refresh family or issuance history). | Decided 2026-10-09 |
| E63 | Access token lifetime is 15 minutes by default; a resource server may set a shorter maximum (`max_access_token_seconds`), never a longer one (EXC-4, REF-5 as amended). | RFC 9700 §4.14.3 (short-lived access tokens). | One fixed lifetime; a per-service-provider lifetime. | Decided 2026-10-09 |
| E64 | The service provider's Login.gov sign-in must be live for the first exchange; afterwards the refresh family carries access independently of the browser session (EXC-12, REF-6; E2 confirmed). | RFC 8693 is silent on subject-token freshness; RFC 6749 §6. | Accept any unrevoked subject token. | Decided 2026-10-09 |
| E65 | Delegated tokens are opaque references (random string, stored as a digest); a resource server learns everything by introspection (EXC-20). | RFC 7662; RFC 9068 (JWT access tokens) considered and not adopted. | Signed JWT access tokens: claims readable by the service provider that carries them, and revocation would still need introspection. | Decided 2026-10-09 |
| E66 | Exactly one `resource` per exchange; one token has one audience (EXC-1 confirmed). | RFC 8707 §2.1 permits several `resource` values; RFC 8693 §2.2.1. | Several resources yielding several tokens or one multi-audience token. | Decided 2026-10-09 |
| E67 | A refusal because the person has not approved, or no longer approves, the application that owns the resource is `consent_required` naming the `token_exchange:<value>` scope, given only to an authenticated caller for a registered resource; other resource problems stay `invalid_target` (EXC-3 as amended, E26 narrowed). | OIDC Core §3.1.2.6 defines `consent_required`; RFC 8693 §2.2.2 permits the RFC 6749 error set and extensions. | `invalid_target` for every consent problem (E26 as first written). | Decided 2026-10-09 |
| E68 | The refresh family's absolute lifetime is 12 hours from the first exchange for every grant, remembered or not, never past `remember_until` (REF-5 as amended). | NIST SP 800-63B §4.2.3 (AAL2 reauthentication at 12 hours). | End the family with the Login.gov session for non-remembered grants; a 4-hour default. | Decided 2026-10-09 |
| E69 | Reuse of a rotated refresh token revokes the family, emits `delegated-access-revoked` with `reason: refresh_token_reuse` and logs an analytics event (REF-4 as amended). | RFC 9700 §4.14.2. | Revoke silently; refuse the request only. | Decided 2026-10-09 |
| E70 | While the service provider's Login.gov session is live, introspection releases the agency's bundle in userinfo shape; after it ends, only `sub`, `delegation_id` and email, stated with `attributes: "identifiers_only"` (INT-10 as amended). | RFC 7662 §2.2 (extension members); PII is decryptable only in the live session. | Cache PII for the family's lifetime; release nothing after the session. | Decided 2026-10-09 |
| E71 | The agency's `sub` is the agency-level pairwise identifier (`AgencyIdentity` uuid), created at first introspection if absent; no `identities` row is created (INT-5 as amended). | OIDC Core §8 (pairwise subject identifiers); Login.gov's per-agency `sub`. | A per-resource-server identifier; creating the agency SP identity. | Decided 2026-10-09 |
| E72 | Who may introspect: the resource server in `aud` (`private_key_jwt`) gets the full response; the public-client service provider gets a limited response for its own token with a DPoP proof over the token from the bound key (INT-1, INT-2, INT-14 as amended); anyone else `{"active": false}`. | RFC 7662 §2.1 (caller authentication); RFC 9449 §4.3 (`ath`). | Resource servers only (INT-2 as first written); a separate status endpoint for service providers. | Decided 2026-10-09 |
| E73 | No hard rate limits (no 429) on exchange, refresh or introspection for registered callers, and no published cache window: volumes and error rates are monitored against configurable alert thresholds, runaway callers are the infrastructure layer's concern, and agencies introspect on every call (EXC-8, INT-7, INT-8, REF-13 as amended; supersedes E5, E22). | RFC 6749 §10 (no normative rate-limit rule); RFC 7662 §4 (introspection per request is the baseline). | Per-caller ceilings (E22); a 60-second cache window (INT-8 as first written). | Decided 2026-10-09 |
| E74 | The Attempts API plan of §8 stands in full (buffer, release at consent with the consented event and historical release, live forwarding, token events with `delegation_id`); delivery stays behind the master switch pending privacy review. | RFC 8936 / Shared Signals Framework (the existing Attempts API). | A single token-issued event only (`sbx-taigrr`); delivery only to agencies the person signed in to directly. | Decided 2026-10-09 |
| E75 | A remembered approval reused on a later sign-in sends that sign-in's events and a `remembered: true` consented event to the agency every time (ATT-5, ATT-13 confirmed). | — | One consented event per remembered grant for its lifetime. | Decided 2026-10-09 |
| E76 | `sp_return_logs` gains one marker column, `access_type`, plus a reference to the issuance record; the acting service provider, resource server and in-session proofing are read by join from `token_exchange_tokens` and the grant (BIL-4, BIL-6, BIL-11 as amended). | — (billing is outside the protocol); the reviewer's note on `token-exchange2-login`. | Three further columns on the return log (BIL-4 as first written). | Decided 2026-10-09 |
| E77 | The sign-in waiver cache entry, keyed by the digest of the service provider's access token, lives one hour (BIL-13 as replaced). | — | A TTL equal to the 12-hour session lifetime. | Decided 2026-10-09 |
| E78 | On a cache miss the exchange falls back to a database lookup scoped to the user's sign-in with that service provider and writes the adjustment; the exchange is never blocked. The fallback's over- or under-billing risk is flagged for the data team (BIL-15). | — | Proceed with no adjustment and alert (the reviewer's first proposal); refuse the exchange. | Decided 2026-10-09; data team review pending |
| E79 | When the person proofed in a delegated sign-in, every agency that received a delegated token is billed for it, proofing included, and the service provider's sign-in is waived (BIL-8 as amended). | — | Service provider upfront; first agency only; a split. | Decided 2026-10-09 |
| E80 | `requested_token_type` is REQUIRED on every exchange and the service provider chooses the format; the resource server's `token_format` is informational for now (EXC-21, SAML-1, SAML-3 as amended). Flagged for review: Login.gov could select the format from the API's registration. | RFC 8693 §2.1 makes `requested_token_type` OPTIONAL with an issuer default; Login.gov requires it so the choice is explicit. | Default to the API's `token_format` when absent; refuse a format the API did not register. | Decided 2026-10-09; review flagged |
| E81 | SAML assertions have a five-minute `Conditions` and subject-confirmation window, are always signed, and are encrypted to the agency's registered certificate when present (SAML-4, SAML-6 as amended). | SAML Core §2.5.1; SAML Profiles §4.1.4.2 (short validity for bearer assertions). | One-hour `Conditions` with a five-minute subject-confirmation window (2026-09-28 decision). | Decided 2026-10-09 |
| E82 | No per-resource-server `dpop_required`: binding follows the client type only (public always, confidential never); the column, seeder key and fixture key are removed (EXC-9, ONB-2 as amended; supersedes E23's per-resource-server clause). | RFC 9449 §5 (`dpop_bound_access_tokens` is client metadata). | Keep the flag as a second control. | Decided 2026-10-09 |
| E83 | DPoP proof algorithms accepted are `ES256` and `RS256`, advertised in `dpop_signing_alg_values_supported` (DISC-2 confirmed). | RFC 9449 §5.1; RFC 7518. | `ES256` only. | Decided 2026-10-09 |
| E84 | Delegation discovery metadata (`grant_types_supported` additions, `introspection_endpoint`, `revocation_endpoint`, `token_endpoint_auth_methods_supported`, `dpop_signing_alg_values_supported`) appears only while `token_exchange_enabled` is true (DISC-5 confirmed). | RFC 8414 §2; OIDC Discovery 1.0 §3. | Always advertise. | Decided 2026-10-09 |
| E85 | The Department of State's selfie and document data are released only at userinfo to the direct service provider on the document-images allow-list, with the `document_images` scope and biometric consent; delegated tokens are refused at userinfo so they never fetch them; the feature and its artifact store are enabled in the sandbox only and no delegated channel is built this phase (INT-16, DOC-1). | OIDC Core §5.3 (userinfo); RFC 9449 §7 (bound token at userinfo). | An encrypted selfie member in the introspection response; a SAML assertion to State; removing the direct feature. | Decided 2026-10-09 |
| E86 | Encrypted userinfo responses are planned, not built: the bundle as a JWE to the certificate registered for the service provider the presented token belongs to, State's attributes first (UINF-1). | OIDC Core §5.3.2 (`userinfo_encrypted_response_alg`/`enc`); RFC 7516. | Per-attribute encryption of the selfie only; no encryption. | Planned 2026-10-09 |
| E87 | `config/delegated_access.localdev.yml` is the single fixture contract between the identity-idp seed task and the `identity-sts-sinatra` harness (one public-client service provider, two applications with one `oauth` and one `saml2` API, the Department of State direct record); the sandbox seeds the same file with environment hostnames (§14.5 as amended). | — | Separate fixtures per repository; `service_providers.localdev.yml` additions. | Decided 2026-10-09 |
| E88 | The maximum remember period is 12 months for every application, `read_write` included (CON-9 confirmed). | — | A shorter remember period for `read_write` applications. | Decided 2026-10-09 |
| E89 | The consent screen's service provider card states the per-sign-in access duration (up to 12 hours) in one sentence and says nothing about Attempts delivery to agencies (CON-26). | — | A fraud-signal disclosure sentence on the screen; no duration sentence. | Decided 2026-10-09 |
| E90 | The account page lists remembered grants only, shows current state only (no usage, no history), and offers a page-level End all delegated access through a confirmation page (ACC-1, ACC-2 as amended, ACC-6). | — | Listing live single-authorization grants; issuance times per row; no end-all action. | Decided 2026-10-09 |
| E91 | A delegated-access history view (approvals, revocations with reason, token issuance and refresh events, 12 months) is planned, sourced from the grant rows and the issuance record with no new table (ACC-7). | — | A dedicated history table; account history events only. | Planned 2026-10-09 |
| E92 | Per-site keys are ported as their own feature (pull requests #13618, #13619): `SiteKeys::RecipientJwk` accepts only a P-256 public JWK, `SiteKeys::Sealer` uses ECDH-ES + HKDF-SHA256 + AES-256-GCM with info and AAD `"login.gov site key wrap v1\n<client_id>"`, and the per-user root is wrapped under the password with the profile-PII scheme, created only for allow-listed service providers, re-wrapped on password change and deleted on password reset; nothing releases a key yet and `site_key_enabled` defaults off (§17). | RFC 8037 and RFC 7518 §6.2 (EC public JWK members); RFC 7518 §4.6 (ECDH-ES), RFC 5869 (HKDF), NIST SP 800-38D (GCM). | Port the whole series at once; defer until release lands; a server-held per-site key with no password wrap. | Decided 2026-10-09 (D56) |
| E93 | The service provider reference application is a browser public client: PKCE, a non-extractable WebCrypto DPoP key held as an IndexedDB `CryptoKey` (new key per sign-in), and the code exchange, token exchange, refresh, revocation and agency API calls all made from the browser with DPoP proofs, including the `DPoP-Nonce` retry of RFC 9449 §8; the server is static hosting plus a non-secret JSON configuration with no private key or shared secret (REF-IMPL-1, REF-IMPL-8 as amended). Published as the rewritten `main` of `GSA-TTS/identity-sts-sinatra`; the confidential-client history is not carried over. | RFC 7636 (PKCE); RFC 9449 §4, §5, §8, §10; RFC 9700 §2.1.1 (public clients). | A confidential-client reference; a server that proxies DPoP proofs for the browser. | Decided 2026-10-09 (D57) |
| E94 | Attempts API code is removed from `identity-sts-sinatra` and `identity-saml-sinatra`, which did not have it upstream before this project; `identity-oidc-sinatra` keeps its viewer because upstream `main` already had one (REF-IMPL-3 as amended). | — (demonstration scope, not protocol). | Keep a viewer in every reference application; remove all three. | Decided 2026-10-09 (D58) |
| E95 | The two agency reference APIs add CORS for browser calls (allow `Authorization`, `DPoP`, `Content-Type`; expose `WWW-Authenticate`), and `/api/openid_connect/introspect` and `/api/openid_connect/revoke` carry the same `Rack::Cors` treatment as the token endpoint so a public client can reach them (§5.3, §6.4, §7.6 as amended). | Fetch standard (CORS preflight, `Access-Control-Expose-Headers`); RFC 9449 §7.1, §8 (`WWW-Authenticate: DPoP`, `DPoP-Nonce`). | Keep the two endpoints server-only and have the browser skip revocation and self-introspection. | Decided 2026-10-09 (D59) |
| E96 | Vulnerabilities GitHub reports on the repository are fixed on the base branch when the fix changes no behavior; a fix that would change behavior is reported to the product owner for a decision (implementation plan section 6, item 11). | — (process). | Fix everything immediately; defer everything to the end. | Decided 2026-10-09 (D60) |
| E97 | Re-approval moves live delegated tokens to the replacement approval instead of ending them: when a new approval of the same application supersedes an earlier live row, `TokenExchangeGrant#transfer_live_tokens_to!` re-points the Redis entries and the issuance records at the new row (`DelegatedTokenStore.move_grant`), and a later revocation of that row ends them (CON-11, §7.5). | RFC 8693 is silent; RFC 6749 §4.1 treats a new authorization as a new grant. | Cascade on every revocation reason, `superseded_by_new_consent` included, so a re-approval briefly interrupts the service provider. | Decided 2026-10-10; rationale: the person has just re-approved the same application, so nothing they hold should stop working |
| E98 | DPoP proof freshness window is ±300 s around now, configurable (`dpop_proof_max_age_seconds`), with each `jti` kept single-use in Redis for twice the window; no `DPoP-Nonce` (EXC-19, Appendix C, E28 and E57 as amended). | RFC 9449 §4.3 item 10 (acceptable window is the server's choice), §11.1. | 60 s back / 10 s forward as written in Appendix C. | Decided 2026-10-10; rationale: clock skew at partners, since the server nonce that would otherwise bound freshness is deferred (E57) |
| E99 | The refresh family's clock starts at the exchange that opens the family: every row's `expires_at` is `family_end` counted from that exchange, bounded by `remember_until`, and another exchange under the same approval opens another family with its own period (REF-5 as amended, applied per family). | RFC 6749 §6 and RFC 9700 §4.14 leave refresh-token lifetime to the authorization server. | One clock per approval from its first exchange, which would make late tokens expire within minutes unpredictably. | Decided 2026-10-10 (D61) |
| E100 | A service provider's introspection carrying a proof that verifies but is signed by a key other than the token's answers `{"active": false}`; 401 `invalid_dpop_proof` with a `WWW-Authenticate: DPoP` challenge is reserved for a proof that fails on its own terms; a caller with no credential, or a `client_id` that is not a public client approved for delegation, also answers `{"active": false}` (INT-1, INT-3 as amended). | RFC 7662 §2.2 (no reason for an inactive token), §2.3; RFC 9449 §7.1. | 401 for every proof problem, the wrong key included, which would tell a token holder without the key that the token exists. | Decided 2026-10-10 (D62) |
| E101 | `jti` in the active response is the hex SHA-256 digest of the token (INT-4 as amended), and `session_live` (boolean, always present for the resource server) replaces `attributes: "identifiers_only"` as the member stating whether the bundle or only identifiers and email are present (INT-10, INT-12 as amended). | RFC 7662 §2.2 (`jti`; extension members permitted); RFC 7519 §4.1.7. | A second random identifier per issuance; the `attributes` string member present only sometimes. | Decided 2026-10-10 (D63) |
