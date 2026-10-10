# SAML 2.0 Core and Profiles (OASIS)

SAML 2.0 Core defines the assertion: its structure, subject and subject confirmation, conditions
(audience, validity window), statements, signing and encryption. SAML 2.0 Profiles defines how a
relying party processes a bearer assertion, including replay protection. In this repository a
delegated token for a SAML-consuming agency API is a bare, signed (and usually encrypted) SAML 2.0
assertion returned in the RFC 8693 token response; the agency validates it locally and never calls
Login.gov per request. Canonical texts:
Core https://docs.oasis-open.org/security/saml/v2.0/saml-core-2.0-os.pdf;
Profiles https://docs.oasis-open.org/security/saml/v2.0/saml-profiles-2.0-os.pdf

## Sections this implementation relies on

- **Core §2.3.3 `<Assertion>`.** `ID` (an `xs:ID`), `IssueInstant`, `Version="2.0"`, `<Issuer>`,
  optional `<ds:Signature>`, `<Subject>`, `<Conditions>`, statements. `SamlIdpExtensions::AssertionBuilder#fresh`
  (`lib/saml_idp_extensions/assertion_builder.rb`) emits them in the gem's order;
  `DelegatedSamlAssertion.new_assertion_id` (`app/services/delegated_saml_assertion.rb`) chooses an
  `ID` starting with an underscore (XML Schema Part 2 §3.3.8) whose digest keys the live entry
  (SAML-7 as amended, D26). `issue_instant:` pins `IssueInstant` to the issuance record.
- **Core §2.3.4 `<EncryptedAssertion>`.** An assertion may be encrypted (XML Encryption) to the
  relying party's key. `DelegatedSamlAssertion#encryption_opts` encrypts to the resource server's
  registered certificate with the application's block cipher (or `aes256-cbc`) and `rsa-oaep-mgf1p`
  key transport, after signing (`builder.encrypt(sign: true)`); SAML-6, SAML-13; D45.
- **Core §2.4.1.1, §2.4.1.2 Subject confirmation.** Method `bearer`; `<SubjectConfirmationData>`
  attributes `NotOnOrAfter`, `Recipient`, `InResponseTo` are all optional. The builder extension emits
  `InResponseTo` only when there is a request ID (the gem wrote an empty one, which relying parties
  reject) and takes `subject_confirmation_expiry:`; `DelegatedSamlAssertion#builder` sets
  `Recipient` to the resource server identifier (SAML-4, E20).
- **Core §2.5.1 `<Conditions>`, §2.5.1.1 processing.** `NotBefore`/`NotOnOrAfter` bound validity;
  a relying party MUST treat an assertion with a condition it does not understand as Invalid.
  Both `NotOnOrAfter` values are the issuance record's lifetime (`token_exchange_saml_assertion_ttl_seconds`,
  300) from `issued_at`; no condition type other than `AudienceRestriction` is emitted (SAML-4 as
  amended, SAML-11, E17: a Delegation Restriction condition was rejected because it would make
  delegation-unaware agencies reject the assertion).
- **Core §2.5.1.4 `<AudienceRestriction>`.** Valid only if the relying party is one of the listed
  audiences. `Audience` is the resource server identifier and nothing else (`#builder`); one
  assertion is good at one API (SAML-4, mirrors RFC 8707).
- **Core §2.7.2 `<AuthnStatement>`, §2.7.3 `<AttributeStatement>`.** `AuthnInstant` and
  `AuthnContextClassRef` describe the sign-in; attributes carry `Name`, `NameFormat`, `FriendlyName`.
  `#authn_instant` is the service provider sign-in's `last_authenticated_at`; the context is the
  verified-identity ACR; `#asserted_attributes` is `AttributeAsserter`'s bundle plus
  `delegation_scopes`, `delegation_id`, `actor` and `dpop_jkt` (SAML-5, SAML-14; E17, E30).
- **Core §5 Signature.** Enveloped XML Signature referencing the `ID`, with the signing certificate
  the metadata publishes. Signed with the current `SamlEndpoint` key; `Issuer` is the metadata
  `entityID` (`SamlIdp.config.base_saml_location`) because `ruby-saml` validators compare both (SAML-11).
- **Core §8.3.7 Persistent name identifier.** `NameID` format persistent, an opaque pairwise
  identifier. `#builder` passes `NAME_ID_FORMAT_PERSISTENT` with `uuid` re-pointed at
  `DelegatedTokenClaims#agency_sub`, the value introspection reports as `sub` (SAML-4).
- **Profiles §4.1.4.2 `<Response>` usage.** A bearer `<SubjectConfirmationData>` MUST carry
  `Recipient` and `NotOnOrAfter`, MUST NOT carry `NotBefore`, and `InResponseTo` MUST match the
  request when there is one. Honored as above; there is no request, so no `InResponseTo`.
- **Profiles §4.1.4.5 Replay.** The relying party MUST ensure a bearer assertion is not replayed,
  remembering `ID` values until `NotOnOrAfter`. Login.gov issues a fresh assertion on every refresh
  (`OpenidConnectRefreshTokenForm#mint!`, new `ID` and windows); each agency declares at onboarding
  whether it treats assertions as single-use (SAML-10; the reference resource server does by default).

## Deliberate choices and deviations

- **The token is the bare assertion**, base64url without padding, not a `<samlp:Response>`
  (RFC 8693 §3, E15); browser-POST delivery is out of scope.
- **Five-minute windows** for both `Conditions` and `SubjectConfirmationData` (D45), down from the
  browser flow's one hour, so a revoked approval is dead at every validator within five minutes
  (companion §15.5; revocation is otherwise seen only at the next refresh).
- **`actor` is an attribute, not a Delegation Restriction condition** (E17, companion §15.4
  "Parity with the OAuth `act` claim"): an unaware API still accepts the assertion.
- **Identity attributes follow the agency's bundle and the session state**: full bundle while the
  service provider's sign-in is live, identifiers and email afterwards, signaled by
  `session_live: false` on the token response (SAML-5b, D73; `#identifiers_only?`).
- **Always signed; encrypted when a certificate is registered** (D45); `locale` and x509 attributes are never emitted.
- **Revocation by `ID` or encoded plaintext assertion ends that assertion only** (D69, E107); an
  encrypted assertion cannot be the `token` (SAML-12).
- **Gem behavior carried as a prepended module** until upstreamed; browser-flow output is byte-identical (E20, SAML-15).

## Questions this digest answers

- Why is there no `InResponseTo`? There is no AuthnRequest; Core §2.4.1.2 makes it optional and an empty value is rejected by relying parties.
- How long is an assertion valid? 300 seconds by default, both windows, capped by the API's maximum and the family end.
- Why not use SAML's Delegation Restriction condition for the actor? Core §2.5.1.1 would make unaware agencies reject every delegated assertion (E17).
- What does the agency validate? Signature against `/api/saml/metadata`, `Audience`, `NotOnOrAfter`, `Recipient`; then `delegation_scopes` per endpoint (companion §15.7).
- Can an agency present one assertion for several calls? Only if it declared that it accepts reuse within the window (SAML-10); otherwise refresh before each call.
- Where is the key binding for a bound family? The `dpop_jkt` attribute; `ath` is over the base64url assertion as presented (E30).
- Which identifier is the `NameID`? The agency-level pairwise identifier, same as introspection's `sub`.

## When to fetch the full text

Read Core §2.4, §2.5 and §5 and Profiles §4.1.4 in full before changing the builder, windows or
attribute statement. Core: https://docs.oasis-open.org/security/saml/v2.0/saml-core-2.0-os.pdf
Profiles: https://docs.oasis-open.org/security/saml/v2.0/saml-profiles-2.0-os.pdf
