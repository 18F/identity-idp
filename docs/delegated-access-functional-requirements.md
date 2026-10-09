# Login STS and Dept of State Functional Requirements

**Status:** Draft for review
**Date:** 2026-10-09 (consent granularity, pre-approval and content decisions of 2026-10-09 applied; see Appendix D)
**Companion document:** *Delegated Access for Login.gov — Requirements* (`delegated-access-requirements.md`), which specifies how the Secure Token Service is built. This document states *what* the capability must do and leaves *how* to the companion document.

---

## 1. Purpose and how to read this document

America.gov is defining business cases in which a member of the public uses America.gov to reach services and information held by federal agencies. Each case needs the person, America.gov, and the agency to interact in a way that is secure and trusted: the agency must know who the person is and that the person authorized the interaction, the person must be able to see and withdraw that authorization, and the agency must keep the fraud signals and billing it receives from direct sign-in today.

Login.gov offers two integration patterns to meet those cases. This document states the functional requirements for the primary pattern, and for the Department of State use case in particular:

- **Secure Token Service (STS), or delegated access.** A third-party service provider that the person has signed in to obtains a short-lived token to call an agency's API on that person's behalf, after the person approves that agency on Login.gov's consent screen. This is the pattern for the known business cases, including the Department of State.
- **Third-party-initiated login.** America.gov sends the person's browser to an agency's own service, and the agency signs the person in through Login.gov as an ordinary service provider. Nothing is delegated. This is retained as an alternative (Appendix C) for cases that need it.

The service provider may use AI in its own service. The capability is not built for AI; it is a standards-based implementation for any approved third-party service provider.

Each section has three parts:

- **Objective** — the outcome in one or two sentences.
- **Functional requirements** — numbered `FR-<area>-<n>`, using MUST, SHOULD and MAY as in RFC 2119. Each states what the system does, not how it is implemented. Current parameter values (lifetimes, limits) are given in parentheses; they are defaults, not requirements, unless marked.
- **Questions to resolve** — points a product owner, privacy officer, agency partner or security reviewer must decide before the requirement is final.

Fictitious agency and service names are used in examples.

### 1.1 Terms

| Term | Meaning |
|---|---|
| **Person / user** | The member of the public who signs in to Login.gov. |
| **Service provider** | The application the person signs in to, which then acts for them at other agencies (America.gov in the first business cases). This is Login.gov's term for what OAuth calls the client and OpenID Connect calls the relying party. |
| **Target agency** | An agency whose API the service provider wants to call on the person's behalf. |
| **Application** | A service an agency registers with Login.gov for delegated access: the agency's own record for that service, carrying the consent content and owning one or more agency API URLs. An agency may register several applications. Consent is given per application. |
| **Agency API** | One URL (resource server) belonging to an application; what a delegated token is issued for. |
| **Delegation** | The person's approval for one service provider to use one application of one agency on their behalf. Consent is given per application; the APIs the application exposes are listed under it for information. |
| **Delegated token** | The credential Login.gov issues to the service provider for one agency API of an approved application. |
| **Consent screen** | Login.gov's existing screen shown before the person is returned to a service provider, where attribute sharing is approved; delegation approvals are added to it. |
| **Third-party-initiated login** | The OpenID Connect pattern (Core 1.0 section 4) in which a third party sends the person to an agency's login initiation address and the agency signs the person in itself. |

---

## 2. Scope and business-case fit

### Objective

Each America.gov business case is assigned to the pattern that fits it. Login.gov supplies the patterns; America.gov defines the cases.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-FIT-1** | The STS MUST be the default pattern. Login.gov MUST also be able to support a business case that uses third-party-initiated login (Appendix C), alone or alongside the STS. |
| **FR-FIT-2** | Each business case MUST be assigned to a pattern, with the reason recorded, before an integration date is committed. |
| **FR-FIT-3** | The STS MUST be used when the service provider calls an agency API from its own server, combines information from several agencies, continues to act within a bounded window while the person is not present, or passes sensitive attributes to an agency that the service provider itself must not see. |
| **FR-FIT-4** | Third-party-initiated login MAY be used when the agency must interact with the person directly in its own service or run its own workflow with the person present. |
| **FR-FIT-5** | Neither pattern MAY raise the identity or authentication assurance of the person above what Login.gov established for the sign-in in question. Where an agency needs a higher level, the service provider's sign-in MUST be performed at that level (see section 11 for the Department of State). |

### Questions to resolve

1. Which America.gov business cases exist today, and who at America.gov owns the list? The known cases are the Department of State passport case, SSA and CMS record access, and a cross-agency dashboard, all assigned to the STS.
2. Who decides the pattern for each case: Login.gov, America.gov, or the agency? What happens when they disagree?
3. Is there a business case that neither pattern fits? If so, is the gap in Login.gov or in the agency?
4. Should Login.gov publish the fit criteria to agencies as part of onboarding, so agencies can propose a pattern themselves?
5. When a State API requires facial-match verification, every America.gov sign-in that requests it must perform that verification. Should America.gov request State's API only when the person starts a passport application, so other America.gov sign-ins are not held to that standard?

---

## 3. Partner onboarding

### Objective

Before any delegation can happen, Login.gov knows which service providers may ask for it, which agency APIs can be delegated, and what the person will be told about each agency and its APIs.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-ONB-1** | Login.gov MUST keep an approved list of service providers permitted to request delegated access. A service provider not on the list MUST NOT be able to request or obtain a delegated token. |
| **FR-ONB-2** | Login.gov MUST keep a registry of applications available for delegation. Each application MUST identify the agency that owns it, the delegation scope value a service provider uses to request it, which service providers it accepts (none listed meaning any approved service provider), and each of its agency API URLs with how that API proves its identity to Login.gov and whether it consumes OAuth tokens or SAML assertions. |
| **FR-ONB-3** | Each application MUST carry agency-written, plain-language content for the consent screen: a display name, what it lets the service do, what information it provides, whether it is read-only or can make changes, and where to learn more. The agency itself MUST have a public name, logo, a short description and a learn-more link. Agency and application content are separate because they may differ. Content MUST be maintained in Login.gov's partner Dashboard so it can be updated regularly; every edit MUST be versioned and marked as material or not (FR-CEN-5). |
| **FR-ONB-4** | Each service provider MUST supply content describing itself: who operates it (name and type of organization), what the service does, how it handles the person's information, whether it uses AI or automated decision-making and for what, a privacy policy, and a support contact. |
| **FR-ONB-5** | Login.gov MUST review and approve partner content before it is shown to the public, and MUST record who approved it and when. |
| **FR-ONB-6** | Partner content MUST be available in every language Login.gov supports, with English as the fallback when a translation is missing. |
| **FR-ONB-7** | Login.gov MUST be able to disable a service provider, an agency, or a single agency API without deleting it, and disabling MUST take effect at the next use of any related token. |
| **FR-ONB-8** | Login.gov MUST define the list of delegable agency APIs. A service provider MUST NOT be able to add to it or alter it through its requests. |
| **FR-ONB-9** | Onboarding MUST use Login.gov's existing, reviewed partner-configuration process (the partner Dashboard synced to the identity provider, and the configuration repository for production), not a separate path. The Dashboard MUST gain the fields FR-ONB-2 to FR-ONB-4 require; this is a dependency on a separate repository. Until it is met, a reviewed seed file and task on the identity provider MAY load the same data in local, review and sandbox environments, never in production. |

The Service Provider form and the Agency Resource API form in the *Consent screen mockup* folder are the current drafts of the questions partners answer.

### Questions to resolve

1. Who at Login.gov approves partner-written consent content, against what standard (reading level, length, prohibited claims), and how long does approval take?
2. Who translates partner content, and who pays for it: the partner or Login.gov?
3. Should an agency be able to restrict which service providers may use its APIs, or is approval of a service provider by Login.gov enough for every agency?
4. When an agency changes its content, must every affected person approve again, or only when the meaning changes? Who judges that?
5. What is the maximum number of APIs an agency may register, so its entry on the consent screen stays readable?
6. Does Login.gov need a contractual or policy instrument with the service provider covering its use of delegated access, separate from the existing agreement for sign-in?
7. How does an agency declare whether it wants OAuth tokens or SAML assertions, and can it change later?

---

## 4. Consent: user experience

### Objective

The person decides, application by application, which agency applications the service provider may act at on their behalf, with enough information to decide, and can see, grant in advance and withdraw those decisions from their account. Consent is per application, not per agency and not per API, because people think in terms of the application they use; the APIs each application exposes are listed under it so the person knows what they are approving. (Decided 2026-10-09; see Appendix D.)

### Functional requirements — the consent screen

| ID | Requirement |
|---|---|
| **FR-CUX-1** | Consent MUST be collected on Login.gov's existing consent screen, so the person sees one consent step at sign-in, not two. |
| **FR-CUX-2** | The screen MUST tell the person who is asking: the service provider's name and logo, what it does, who operates it, whether it uses AI and for what, how it handles their information, and where to learn more. |
| **FR-CUX-3** | The screen MUST present one row per requested application, labeled with the owning agency's public name and logo and the application's display name, grouped by agency. Under each application the screen MUST show the agency's description, the application's description, the information the service will receive, whether access is read-only or can make changes, a link to learn more, and the application's API URLs. The APIs are shown for information; the person approves the application as a whole. |
| **FR-CUX-4** | Applications named in the service provider's request MUST be shown selected and locked: they are a condition of the sign-in, as requested attributes are today. Nothing not named in the request MAY appear selected or be approved by this screen. |
| **FR-CUX-5** | The person declines a requested application by cancelling the sign-in. There is no partial approval of a request: the service provider either receives every application it requested or no sign-in. The screen MUST say so plainly next to the locked rows. |
| **FR-CUX-6** | The person MUST be able to cancel and return to the service provider without approving anything. |
| **FR-CUX-7** | The person MUST be offered the choice to have Login.gov remember the approvals given on this screen for a limited period (currently one year). The default MUST be not to remember; an approval that is not remembered is valid for this sign-in only. The screen MUST explain what remembering means and where to review or change approvals. Approvals given in advance from the account page (FR-CUX-13) are always remembered for the same period, counted from the moment they were given. |
| **FR-CUX-8** | The screen is shown only when a requested application lacks a current remembered approval (FR-CEN-5). Requested applications the person already approved, on an earlier screen or from the account page, are shown selected and locked like the others, marked as already approved; a requested application without an approval is marked as new. |
| **FR-CUX-9** | Everything shown about a service provider or agency MUST come from content Login.gov approved at onboarding. Nothing in the service provider's request MAY alter what the person sees, and partner-written content MUST NOT be able to execute or alter the page. |
| **FR-CUX-10** | The screen MUST meet Login.gov's accessibility and plain-language standards and MUST be available in every supported language. |
| **FR-CUX-11** | The layout and wording MUST follow the approved consent-screen design (*Consent screen mockup*), adjusted for agency-level choices, and MUST use fictitious agency and service names in any published example. |

### Functional requirements — reviewing and revoking

| ID | Requirement |
|---|---|
| **FR-CUX-12** | The person's Login.gov account MUST include a page that, for each service provider approved for delegation the person has connected to, lists every registered application that accepts that service provider, grouped by agency, showing for each whether it is approved, when, how long the approval remains, whether a token is active now, the APIs covered and whether each is read-only or can make changes. |
| **FR-CUX-13** | From that page the person MUST be able to approve an application in advance (after seeing the same content the consent screen shows), revoke a single application, or revoke an entire service provider. An advance approval is a remembered approval (FR-CUX-7) and is honored by the consent screen (FR-CUX-8). |
| **FR-CUX-14** | The page MUST be reachable from the existing list of connected services. |

### Questions to resolve

1. **Should the screen offer "approve all"?** With one choice per agency there are few boxes; a select-all control speeds approval but is what produces consent fatigue in the first place.
2. **Where does the information on the consent screen come from?** Service provider content comes from the Service Provider form; agency and API content comes from the Agency Resource API form; both are approved by Login.gov and stored before use. Nothing comes from the live request. Does privacy or legal need to review the forms' questions?
3. Should "remember my approvals" apply to all approvals at once, or be offered per agency?
4. Is one year the right maximum for a remembered approval? Should agencies whose APIs can make changes have a shorter maximum?
5. How many agencies can one screen hold before it needs paging or a summary view?
6. Should the screen say that approving an agency also means Login.gov will send that agency the person's sign-in and fraud-signal events (section 8)? Does privacy consider that covered by the existing Privacy Impact Assessment?
7. Should the person be able to pick which email address each agency receives, or does each agency receive the one shared with the service provider?
8. Should the screen show the duration of access the service provider will have (currently up to 12 hours per sign-in) in addition to the remember period?
9. What does the person see when a requested agency is temporarily disabled: an explanation, or simply its absence?
10. Should a "learn more" link open the agency's site in a new tab, and is leaving the consent screen acceptable mid-decision?
11. Should Login.gov run comprehension testing of the screen with members of the public before launch, and what comprehension rate is acceptable?
12. Should the person receive an email or account notification when a new delegation is approved or revoked, as they do for other account changes?
13. Should the account page also show delegations that were approved for one sign-in only and are still active (up to 12 hours), or only remembered ones?
14. Should there be a single "end all delegated access" action?
15. Should the page show a history of past delegations and revocations, or only current ones? How long should history be kept?
16. Should the person be able to see what the service provider actually did (number of calls, last use)? Login.gov knows when tokens were issued and renewed, not what the agency returned.

---

## 5. Consent: enforcement

### Objective

What the person approved is exactly what the service provider can do, no more, for as long as the approval is valid. Login.gov checks the request before the person sees it, records every decision, and makes revocation take effect everywhere.

### Functional requirements — what may be requested

| ID | Requirement |
|---|---|
| **FR-CEN-1** | A service provider MUST request delegated access as part of the person's sign-in request, naming each application it wants by that application's delegation scope value. |
| **FR-CEN-2** | Login.gov MUST refuse a request that names an application that does not exist or is disabled, belongs to a disabled agency, does not accept the requesting service provider, or comes from a service provider not approved for delegation. The refusal MUST be reported to the service provider as an error, not shown to the person as a choice. |
| **FR-CEN-3** | Delegated access MUST be available only for identity-verified sign-ins. |
| **FR-CEN-4** | Existing sign-in behavior for service providers that do not request delegation MUST be unchanged. |

### Functional requirements — when the person is asked

| ID | Requirement |
|---|---|
| **FR-CEN-5** | The consent screen MUST be shown whenever a requested application is not covered by a remembered, unrevoked, current approval. An approval stops being current when the agency, the application or the service provider has made a change to its consent content that it marked as material since the person approved; editorial changes do not re-ask. |
| **FR-CEN-6** | Cancelling the consent screen MUST leave no approval, no sign-in and no record at the service provider or any agency, and MUST NOT affect whether or how the person is asked next time. There is no per-application decline (FR-CUX-5). |
| **FR-CEN-7** | Once the person has answered the screen for a sign-in, they MUST NOT be asked again within that same sign-in. |

### Functional requirements — effect of the decision

| ID | Requirement |
|---|---|
| **FR-CEN-8** | Login.gov MUST issue a delegated token only for an API of an application the person approved, where the approval is still valid: not revoked, not expired, and not superseded by a material change in consent content. |
| **FR-CEN-9** | The service provider MUST be told which applications were approved, and only those. |
| **FR-CEN-10** | An application the person has not approved MUST have no effect anywhere: its APIs MUST NOT be usable, nothing MUST be reported to its agency, and no record of the person MUST be created at it. |
| **FR-CEN-11** | An approval that was not remembered MUST be valid only for the sign-in in which it was given. A remembered approval, whether given on the consent screen or in advance from the account page, MUST be valid for no longer than the remember period counted from when it was given. |
| **FR-CEN-12** | Approving an application MUST NOT create or alter any direct relationship between the person and that application or its agency in Login.gov, and MUST NOT affect any direct sign-in the person has with them. |

### Functional requirements — revocation and records

| ID | Requirement |
|---|---|
| **FR-CEN-13** | Revoking an approval, by the person or by Login.gov, MUST immediately invalidate every token issued under it and MUST be reported to the agency (section 8). |
| **FR-CEN-14** | Disconnecting the service provider from the person's account MUST revoke all of that service provider's approvals. |
| **FR-CEN-15** | Signing out of Login.gov MUST NOT by itself revoke approvals the person chose to remember. Suspension or deletion of the account MUST revoke all of them. |
| **FR-CEN-16** | Disabling an agency, an agency API, or a service provider at Login.gov MUST stop all related delegated access at the next check. |
| **FR-CEN-17** | Login.gov MUST record each approval: which applications were requested and approved, whether it was given on the consent screen or in advance from the account page, the agency, application and service provider content versions the person saw, whether it was remembered, when, and in which sign-in. |

### Questions to resolve

1. May a service provider request agency APIs at a later point in the session (for example, when the person first opens a feature), or only at sign-in?
2. Should Login.gov cap how many agencies or APIs a service provider can request in one sign-in?
3. Should Login.gov tell the person when a request was refused because of the service provider's error, or silently continue sign-in without delegation?
4. When a service provider adds a new API under an agency the person already approved, should the person be re-asked for that agency (as FR-CEN-5 says), or does approving the agency cover any API it later exposes? Re-asking protects the person; not re-asking reduces prompts.
5. When content changes and the approval lapses, should existing tokens stop at once or run to their expiry?
6. Should the person be notified when an approval lapses because of a content change, or only asked again at next sign-in?

---

## 6. Delegated tokens: issuance, renewal, revocation and security

### Objective

A service provider that holds a person's approval can obtain a credential for exactly one agency API, for a short time, from its own server, can keep working for the person for a bounded period, can stop early, and never holds anything beyond what was approved. Delegated access introduces no path weaker than direct sign-in.

### Functional requirements — issuance

| ID | Requirement |
|---|---|
| **FR-TOK-1** | Token issuance MUST follow the OAuth 2.0 Token Exchange standard (RFC 8693) at Login.gov's existing token endpoint; no separate service is introduced. |
| **FR-TOK-2** | Issuance MUST be server-to-server. The service provider MUST prove its identity with a cryptographic key it alone holds. A token obtained in a browser MUST NOT be exchangeable, so a credential stolen from a browser cannot be used to obtain delegated access. |
| **FR-TOK-3** | Each delegated token MUST be valid for exactly one agency API, named by the service provider in the request, so a token stolen from one agency API is useless at any other. |
| **FR-TOK-4** | Delegated tokens MUST be short-lived (currently 15 minutes). |
| **FR-TOK-5** | A delegated token MUST identify the person to the agency, identify the service provider as the party acting, state the approved access, and carry a delegation identifier the agency can use to join the token to fraud-signal events and billing. |
| **FR-TOK-6** | A delegated token MUST NOT be usable to obtain further tokens, and MUST NOT be usable by the service provider to obtain the person's identity attributes from Login.gov. The service provider never receives the person's identity attributes through delegation. |
| **FR-TOK-7** | Issuance MUST be possible only while the person's Login.gov sign-in to the service provider is still active. |
| **FR-TOK-8** | Issuing a delegated token MUST NOT revive a connection the person revoked or alter a direct session the person has with the agency. |
| **FR-TOK-9** | Login.gov MUST be able to issue a SAML 2.0 assertion instead of an OAuth token for an agency API that consumes SAML, with the same access, lifetime rules, record-keeping, and revocation behavior. |

### Functional requirements — renewal and ending access

| ID | Requirement |
|---|---|
| **FR-TOK-10** | Login.gov MUST allow the service provider to obtain a fresh delegated token for the same API without involving the person, for a bounded total period after issuance (currently 12 hours, absolute, not extended by use). |
| **FR-TOK-11** | The total period MUST never extend past the person's remembered-approval period, and for a non-remembered approval MUST end no later than 12 hours after issuance. |
| **FR-TOK-12** | Each renewal MUST retire the renewal credential used. Reuse of a retired renewal credential MUST end all access under that issuance and MUST be reported to the agency as a possible theft, so a stolen renewal credential ends access rather than extending it. |
| **FR-TOK-13** | A renewed token MUST have the same API, access, and delegation identifier as the original; the service provider MUST NOT be able to change them at renewal. |
| **FR-TOK-14** | The service provider MUST be able to end its access early (Token Revocation, RFC 7009). |
| **FR-TOK-15** | Continued access MUST NOT depend on the person's browser session with Login.gov remaining open. |
| **FR-TOK-16** | Login.gov MUST be able to set a shorter total period for a specific service provider or for agencies whose APIs can make changes, but never a longer one. |

### Functional requirements — security

| ID | Requirement |
|---|---|
| **FR-TOK-17** | A service provider MUST NOT be able to widen its own access beyond what Login.gov defined and the person approved. |
| **FR-TOK-18** | Renewal credentials MUST be stored in a form from which the credential cannot be recovered. |
| **FR-TOK-19** | All machine-to-machine proofs of identity, by service providers and by agencies, MUST be short-lived and protected against replay. |
| **FR-TOK-20** | Issuance and renewal MUST be rate-limited per service provider. |
| **FR-TOK-21** | Delegated tokens MUST be opaque to the service provider; their meaning is established only by Login.gov (section 7). |
| **FR-TOK-22** | Login.gov MUST support binding a delegated token to a key the service provider holds (DPoP, RFC 9449): when the exchange or renewal request carries a proof signed by that key, the token MUST be usable only with a fresh proof from the same key, and renewal of a bound token MUST require the same key. An agency MUST be able to require binding for its API, in which case an exchange without a proof MUST be refused. Binding MUST be required for any API reached from a browser-based service provider, where the token is held in the user's browser; America.gov is such a service provider. |
| **FR-TOK-23** | Login.gov MUST report the binding to the agency when it verifies a token (the key thumbprint and a token type of `DPoP`), and the agency MUST verify a proof from that key on every request and refuse a bound token presented without one. A key-bound SAML assertion carries the thumbprint as an attribute. |

### Questions to resolve

1. Is 15 minutes the right token lifetime? Shorter reduces exposure; longer reduces renewal traffic.
2. Is 12 hours the right bound for continued access? It matches the NIST SP 800-63B re-authentication limit for AAL2. Should agencies whose APIs can make changes have a shorter bound (for example, one hour)?
3. Should a service provider be able to request narrower access than it was approved for?
4. DPoP is now required (FR-TOK-22). Remaining question: should Login.gov also issue server nonces (RFC 9449 §8) for proof freshness, at the cost of an extra round trip through the service provider's relay, or is the 60-second issued-at window enough?
5. Is the "sign-in must still be active" rule for first issuance acceptable to America.gov, whose server may act after the person has left?
6. Should the person be told, at consent, that the service provider may keep acting for up to 12 hours after they leave?
7. Should the service provider be required to end access when the person's task is complete, and how would Login.gov know?
8. Which agencies need SAML rather than OAuth, and does any need both?
9. Should the stricter proof-of-identity rules used for delegated access also be applied to existing sign-in integrations?

---

## 7. Agency verification of delegated tokens

### Objective

For every call, the agency can confirm with Login.gov that the token is genuine, current, meant for it, and what it permits, and receives the same identity information it would from a direct sign-in, with the service provider identified as the acting party.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-VER-1** | A delegated token MUST be verified with Login.gov before an agency relies on it. Login.gov MUST provide the means for the agency API to do so. |
| **FR-VER-2** | The agency MUST prove its identity to Login.gov when verifying a token. Login.gov MUST confirm a token, and release anything about the person, only to the agency API the token was issued for. Any other caller, including the service provider that holds the token, MUST learn nothing. |
| **FR-VER-3** | A confirmed token MUST report: who issued it (Login.gov), the person's identifier for that agency (the same one a direct sign-in produces), the approved access, the acting service provider, the assurance levels of the sign-in, when the person last authenticated to the service provider, issuance and expiry times, an identifier for this one token, and the delegation identifier shared by every token under the same approval. Together these are the elements NIST IR 8587 §5.2.1.1 requires of a token an agency relies on. |
| **FR-VER-4** | A confirmed token MUST also carry the identity attributes the agency is entitled to under its existing Login.gov agreement, in the same form a direct sign-in provides them, and nothing more. The set MUST be determined by the agency's agreement, never by the service provider. |
| **FR-VER-5** | Identity attributes MUST be available while the person's sign-in to the service provider is active. After it ends, verification MUST still confirm the token but MUST provide identifiers and email only, and MUST say so. |
| **FR-VER-6** | An invalid, expired, revoked, or foreign token MUST produce a plain "not valid" answer with no reason given. |
| **FR-VER-7** | Login.gov MUST publish how long an agency may rely on a confirmation before asking again (currently 60 seconds). |
| **FR-VER-8** | Verification MUST be rate-limited per agency API. |
| **FR-VER-9** | For SAML, the agency verifies the assertion locally against Login.gov's published signing certificate; the assertion MUST carry the same information as FR-VER-3 and FR-VER-4, and MUST be encrypted to the agency's certificate when one is registered. |

### Questions to resolve

1. **Which Login.gov endpoint performs verification?** Agencies already call Login.gov's user-information endpoint after a direct sign-in. Two options meet FR-VER-1 and FR-VER-2: extend that endpoint so that, for a delegated token, it requires the agency to prove its identity and returns the delegation details alongside the attributes; or offer the standard Token Introspection endpoint (RFC 7662) alongside it. The first reuses the call agencies already make; the second uses the standard built for this purpose and the libraries that support it. Either way, the agency must authenticate, because the service provider also holds the token and a plain bearer call would hand it the agency's attributes.
2. Is it acceptable to agencies that identity attributes are available only while the person's sign-in to the service provider is active, and identifiers only afterwards? What will an agency do with an identifiers-only result?
3. The agency receives the email address the person shared with the service provider. Is that acceptable, or does the agency need its own choice?
4. Should the agency be able to require that the service provider's sign-in met a particular assurance level, or is identity-verified (IAL2) always sufficient?
5. For SAML agencies, a revoked approval leaves an already-issued assertion usable until it expires (up to five minutes at most validators; one hour at the most lenient). Is that acceptable?
6. Agencies must add verification to their APIs. Who funds and supports that work, and what is the expected lead time?

---

## 8. Fraud signals to agencies

### Objective

An agency that accepts delegated access on a person's behalf receives the same sign-in and identity-verification fraud signals it would have received had the person signed in to it directly, plus the events specific to delegation, and nothing about people who declined.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-FRD-1** | When a service provider requests delegation, Login.gov MUST retain the sign-in session's fraud-signal events (sign-in, multi-factor, rate-limit, identity-verification) for possible delivery, whether or not the service provider itself receives such events. |
| **FR-FRD-2** | When the person approves an agency, Login.gov MUST deliver those events to that agency through the existing Attempts API, attributed to the person's identifier at that agency, together with a consent event and the person's identity-verification history (once per agency, as today). |
| **FR-FRD-3** | Nothing MUST be delivered to, and no record of the person MUST be created at, an agency the person declined. |
| **FR-FRD-4** | While the person's sign-in to the service provider remains active, later events (re-authentication, multi-factor change, sign-out, timeout, rate limits) MUST also be delivered to each approved agency. |
| **FR-FRD-5** | Login.gov MUST deliver an event to the agency when a delegated token is issued, when it is renewed, and when access is revoked (with the reason). |
| **FR-FRD-6** | Every delivered event MUST carry the delegation identifier so the agency can join events to API calls, and MUST identify the acting service provider. |
| **FR-FRD-7** | When a remembered approval is reused without showing the consent screen, the agency MUST still receive the events for that sign-in and a consent event marked as remembered. |
| **FR-FRD-8** | Existing Attempts API integrations MUST continue to work unchanged; the new events are additive. |
| **FR-FRD-9** | Retained events MUST be encrypted while held and MUST be discarded when the session ends. |

### Questions to resolve

1. Does Login.gov's Privacy Impact Assessment and SORN cover delivering a person's sign-in events to an agency the person did not sign in to directly, on the basis of a delegation approval? Privacy must confirm.
2. Should the consent screen mention this delivery (section 4, question 6)?
3. An agency not enrolled in the Attempts API receives nothing. Should enrollment be a condition of accepting delegated access?
4. How long does an agency keep delegated events, and does the delegation identifier count as new personal data at the agency?
5. The service provider's own server performs issuance and renewal. Should the events for those carry the service provider's server address, labeled as such, or no network information?

---

## 9. Billing and reporting

### Objective

Delegated use is billed to the agency whose API is used, in the same way direct use is, and Login.gov can report on what was requested, approved, and used.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-BIL-1** | Each delegated use MUST be attributed to the agency whose API was used, at the identity assurance level of the person's sign-in, and recorded in the same billing record as direct use, marked as delegated and naming the acting service provider and API. |
| **FR-BIL-2** | The first use under each approval per sign-in MUST be billable; later uses and renewals MUST be recorded but not billable. |
| **FR-BIL-3** | A person who uses an agency both directly and through delegation in one month MUST be billed to that agency once. |
| **FR-BIL-4** | Existing invoices and reports MUST include delegated use in their totals and SHOULD add a direct/delegated breakdown. |
| **FR-BIL-5** | Login.gov MUST produce a monthly delegation outcomes report, per service provider and agency: delegations requested and declined; approved but never used; and used. It MUST also report identity verifications that occurred in a service provider sign-in that led to no billable agency use. |
| **FR-BIL-6** | The record of which service provider initiated a person's identity verification MUST NOT be changed by delegation. How verification cost is shared between the service provider's and the agency's agreements is a reporting rule, not runtime behavior. |
| **FR-BIL-7** | Billing MUST NOT rely on storing token values. |
| **FR-BIL-8** | The service provider (America.gov) is billed for its own sign-in by default, like any customer. When at least one delegated token is issued for that sign-in, the sign-in MUST become non-billable, because the agencies receiving the tokens are billed instead; this MUST happen together with the first agency charge so that no sign-in is ever billed twice or to no one. A sign-in for which no delegated token is ever issued (the person declined every agency, or the service provider never exchanged) stays billable to the service provider. A consent screen the person cancels completes no sign-in and is billed to no one, as for every service provider today. Reports MUST show, per service provider and month, how many sign-ins were billed and how many were waived because tokens were issued. |
| **FR-BIL-9** | Reports MUST never count a person twice for one agency in one month because they arrived both directly and by delegation, and MUST NOT treat a person already seen directly as new when they later arrive by delegation. The delegated-only share of an agency's billed users MUST be reported alongside the totals. |
| **FR-BIL-10** | Onboarding MUST warn when an agency API's billing identity is not tied to a partner agreement, since delegated use of it would be recorded but never invoiced, and the delegation outcomes report MUST show that status per API. |

### Questions to resolve

1. When a person is identity-verified at the service provider and then uses an agency API by delegation in the same month, who is billed for the verification: the service provider, the first agency, every agency, or a split? (The data to apply any rule is recorded; the rule is not chosen.)
7. America.gov must hold a partner agreement for "billable by default" (FR-BIL-8) to be invoiced; who owns that onboarding step?
2. Should identity-verification outcome reports exclude delegated use, since the verification happened at the service provider?
3. Each agency API must be tied to a billable agreement. What happens to delegated use of an API whose agreement has lapsed?
4. Does America.gov pay anything for delegated access, or only for its own sign-ins?
5. Who receives the delegation outcomes report, and is it shared with agencies and America.gov?

---

## 10. Operations and rollout

### Objective

The capability can be turned on, observed, and turned off by Login.gov, is reviewed before production, and is introduced one partner at a time.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-OPS-1** | The entire capability MUST be behind a single control that Login.gov can turn off, and when off, Login.gov MUST NOT advertise it to partners. |
| **FR-OPS-2** | Login.gov MUST monitor issuance, renewal, verification, and revocation volumes and errors, approved-but-unused delegations, fraud-signal delivery completeness, and billing correlation. |
| **FR-OPS-3** | The capability MUST pass GSA Cyber and the required external security review before production use. |
| **FR-OPS-4** | Rollout MUST proceed from local and sandbox testing with reference applications, to one service provider and one agency in the sandbox, to fraud-signal and billing verification, to production, with a review gate at each step. |
| **FR-OPS-5** | Login.gov MUST provide working reference applications for both partner roles (service provider and agency API, OAuth and SAML) and an automated end-to-end test that partners can run against the sandbox. |
| **FR-OPS-6** | Login.gov MUST publish a partner guide for each role covering the requests, responses, error handling, and a checklist of obligations. |

### Questions to resolve

1. Who supports agencies during integration, and what is the support model after launch?
2. What are the production readiness criteria for each agency beyond passing the end-to-end test?
3. What is the incident process when an agency reports a delegated call it believes it should not have received?

---

## 11. Department of State use case

### 11.1 The business need

The Department of State wants to offer fully online enrollment for a new passport (Form DS-11). State requires a selfie captured during the process so that it can compare it with the passport photo the applicant submits, as part of manual adjudication. State's requirements for this comparison are stricter than a general identity-verified sign-in: the selfie must be fresh and captured under facial-match verification, and previously stored Login.gov selfies cannot be reused for this purpose.

The *Department of State Online Passport Enrollment: Business Case Memo* (in the *Dept of State usecase* folder) records the fraud, brand, financial, and records-retention risks of the originally proposed flow, in which Login.gov would send the biometric to America.gov for packaging. Those risks drive the requirements below: the biometric never passes through the service provider; it is released encrypted to State alone, through the channel State uses to verify the delegated token, under State's own agreement with Login.gov.

### 11.2 Pattern

The Department of State case uses the STS. America.gov is the service provider; State registers its passport enrollment API as an agency API; the person approves the Department of State on the consent screen, with the passport API listed under it; America.gov obtains a delegated token for that API and calls it; State verifies the token with Login.gov and receives the person's identity attributes, including the encrypted selfie, in the verification response. America.gov never receives the biometric because the service provider cannot obtain attributes with a delegated token and verification answers only the agency the token was issued for.

| ID | Requirement |
|---|---|
| **FR-DOS-1** | The Department of State case MUST use the STS (sections 3–10). All general STS requirements apply; this section adds what is specific to State. |
| **FR-DOS-2** | The biometric MUST reach State only through the agency verification channel (section 7) or a SAML assertion issued to State (FR-TOK-9). It MUST NOT be included in the delegated token itself, in anything returned to the service provider, or in any response to a party other than State. |
| **FR-DOS-3** | Because a delegated token never carries higher assurance than the sign-in it came from (FR-FIT-5), the person's sign-in to America.gov MUST itself include the facial-match verification State requires whenever State's passport API is requested. Login.gov MUST perform that verification during the sign-in, before consent, rather than relying on an earlier verification. |
| **FR-DOS-4** | State's passport API MUST be registered as its own agency API whose consent content states, in State's words, that approving the Department of State releases the fresh selfie to State for passport adjudication. |

### 11.3 Capturing the biometric

| ID | Requirement |
|---|---|
| **FR-DOS-5** | When a sign-in requests State's passport API, Login.gov MUST capture a fresh selfie in that sign-in, even for a person who has already verified their identity with Login.gov. A selfie captured in an earlier verification MUST NOT be reused for State. |
| **FR-DOS-6** | Login.gov MUST tell the person, before capture, that the selfie will be released to the Department of State for passport adjudication, who will see it, how long each party keeps it, and that declining means they cannot continue this process online. This notice MUST be specific to the biometric and MUST appear in addition to the consent screen. |
| **FR-DOS-7** | If the person declines the Department of State on the consent screen, the selfie MUST NOT be released and the rest of the sign-in MUST proceed normally. |
| **FR-DOS-8** | Capture MUST meet the same liveness and quality standards as Login.gov's existing facial-match verification, and MUST meet Login.gov's accessibility requirements, including an alternative path for people who cannot complete selfie capture. |
| **FR-DOS-9** | Login.gov MUST record the capture, the consent, and each release as auditable events. |

### 11.4 Delivering the biometric to the Department of State

| ID | Requirement |
|---|---|
| **FR-DOS-10** | Login.gov MUST release the selfie only to the Department of State's registered passport API, in response to that API's authenticated verification of a delegated token the person approved for it, or in a SAML assertion issued to that API. |
| **FR-DOS-11** | The selfie MUST be released only if State's Login.gov agreement includes it as an attribute State is entitled to receive (FR-VER-4). No other agency agreement MAY include it, and the service provider's own agreement MUST NOT. |
| **FR-DOS-12** | The selfie MUST be encrypted end to end to a public key held by the Department of State, so that it is readable only by State and not by Login.gov's edge infrastructure, logs, the service provider, or any intermediary. It MUST be signed by Login.gov before encryption so State can verify its origin and integrity. The remainder of the verification response MAY stay unencrypted, as today. |
| **FR-DOS-13** | The release MUST include enough context for adjudication: when the selfie was captured, the verification outcome, the assurance level, the person's identifier for State, and the delegation identifier. |
| **FR-DOS-14** | The selfie MUST be available for release only while the person's sign-in to America.gov is active (FR-VER-5). After the sign-in ends, verification MUST still confirm the token but MUST NOT include the selfie, and MUST say so. |
| **FR-DOS-15** | Login.gov MUST NOT retain the selfie beyond its existing identity-verification retention rules because of this release, and MUST NOT create a new store of biometric images for the purpose of release. |
| **FR-DOS-16** | State MUST be able to decrypt, verify, and view the image with tooling it controls; Login.gov SHOULD provide a reference decryption and verification example in the reference agency API (FR-OPS-5). |
| **FR-DOS-17** | Every release MUST be logged with the person's identifier for State, the delegation identifier, the time, and the key used, without logging the image. |
| **FR-DOS-18** | Fraud-signal delivery (section 8) and billing (section 9) for State MUST work exactly as for any other agency API; the biometric adds no exception. |

### 11.5 Alternative: State-operated proofing

| ID | Requirement |
|---|---|
| **FR-DOS-19** | If State chooses to capture the selfie through its own identity-proofing vendor rather than receive it from Login.gov, sections 11.3–11.4 do not apply. The STS still applies to any other State API America.gov uses, and Login.gov's role in the passport case is limited to ordinary sign-in and identity verification of the person. |

### Questions to resolve

1. **Which option does State want:** the selfie from Login.gov (11.3–11.4), or its own capture (11.5)? The memo notes that a second selfie immediately after Login.gov verification is a poor experience for new users, while receiving the selfie from Login.gov creates retention, SORN, and brand exposure for Login.gov.
2. Does releasing a biometric to a partner agency require a new or amended SORN and Privacy Impact Assessment? Today Login.gov releases stored biometrics only under a manual legal process.
3. **Who triggers the facial-match verification in the America.gov sign-in?** Options: America.gov always requests it; Login.gov requires it automatically whenever State's passport API is in the request; or State's API is only offered to people who already completed it in this sign-in. The second keeps the decision with Login.gov and State.
4. Does "fresh" mean captured in this sign-in, or within some window (for example, 24 hours)? What if verification in this sign-in fails: is the sign-in refused, or does it continue without State?
5. With agency-level consent, a person who approves the Department of State approves every State API in the request, including the passport API and its biometric release. Is the separate pre-capture notice (FR-DOS-6) enough, or should the biometric release be the one case that gets its own confirmation on the consent screen?
6. What image format, resolution, and metadata does State's adjudication need? Does State need the ID document photo as well, or the selfie only?
7. Which State key is used for encryption, how is it registered and rotated, and what happens to a release encrypted to a retired key?
8. **Verification response or SAML assertion?** Login.gov's OAuth responses are not encrypted today; SAML assertions are encrypted by default. An encrypted field inside the verification response keeps State on the OAuth path all other agencies use; a SAML assertion reuses existing encryption but puts State on the SAML path. Preliminary engineering estimate for the encrypted field: roughly 1,000–1,400 lines of change.
9. The selfie is available only while the person's sign-in to America.gov is active (FR-DOS-14). State's API must therefore verify the token and retrieve the selfie promptly after America.gov calls it, not later in adjudication. Is that acceptable to State's workflow, and what happens if the first verification misses the window?
10. Login.gov's current rule forces one re-verification per person for a given initiating service provider. State needs a fresh capture on every application, and the initiating service provider here is America.gov, not State. Who owns that policy change, and how is it scoped to the passport API only?
11. Who pays for the re-verification of a person who is already identity-verified? The memo notes this is a net cost to Login.gov under the current model, and under the STS the verification happens in America.gov's sign-in (section 9, question 1).
12. What does the person see if State's comparison fails? America.gov holds the session, so America.gov must present the outcome; what does State tell America.gov, and through what channel?
13. Does the biometric release to State need separate legal review for voluntariness, given that declining ends the online path?
14. Does any of this change if State offers in-person enrollment through USPS as an alternative channel, as the memo favors?

---

## Appendix A — Consolidated decisions awaiting an owner

The questions in this document that most affect scope or schedule, gathered in one place.

| # | Question | Section | Suggested owner |
|---|---|---|---|
| 1 | Pattern assignment for each America.gov business case | 2 | America.gov with Login.gov product |
| 2 | ~~Whether approving an agency covers APIs it exposes later, or re-asks~~ Decided 2026-10-09: consent is per application; adding a URL to an application is a content change and re-asks only if marked material | 5 | — |
| 3 | ~~"Approve all" on the consent screen~~ Decided 2026-10-09: not needed, requested applications are locked | 4 | — |
| 4 | Whether the consent screen discloses fraud-signal delivery to agencies | 4, 8 | Login.gov privacy |
| 5 | Email address released to agencies | 4, 7 | Login.gov product, agencies |
| 6 | Remember period and duration limits for agencies that can make changes | 4, 6 | Login.gov product and security |
| 7 | Verification endpoint: extended user-information endpoint or Token Introspection | 7 | Login.gov engineering and security |
| 8 | Sender-constrained tokens before production | 6 | Login.gov security, GSA Cyber |
| 9 | Verification cost attribution across partners | 9 | Login.gov finance |
| 10 | ~~Agency restriction of service providers~~ Decided 2026-10-09: per application, empty list means any approved service provider | 3 | — |
| 11 | State: selfie from Login.gov or State's own capture | 11 | Department of State, Login.gov leadership |
| 12 | State: who triggers facial-match verification in the America.gov sign-in | 11 | Login.gov product, America.gov, State |
| 13 | State: SORN and PIA for biometric release | 11 | Login.gov privacy and legal |
| 14 | State: verification response or SAML, and encryption key management | 11 | Login.gov engineering, State |
| 15 | State: fresh-capture policy and who pays for re-verification | 11 | Login.gov product and finance |
| 16 | Hand-off and return profile ownership, if the alternative pattern is used | Appendix C | Login.gov, America.gov |

## Appendix B — Traceability to the companion document

| This document | Companion document sections |
|---|---|
| 3 Partner onboarding | §3 Onboarding data model; Service Provider and Agency Resource API forms |
| 4 Consent: user experience | §4.3, §4.7; Consent screen mockup |
| 5 Consent: enforcement | §4.1–4.2, §4.5–4.6, §5.1, §7.5 |
| 6 Delegated tokens | §5, §7, §11, §15 (SAML), Appendix C (DPoP) |
| 7 Agency verification | §6, §15.5, §15.7 |
| 8 Fraud signals | §8 |
| 9 Billing and reporting | §9 |
| 10 Operations and rollout | §10, §12, §13, §14 |
| 11 Department of State | Business Case Memo; companion §6 (attribute release), §15 (SAML); initiative document, Solution Comparison |
| Appendix C Third-party-initiated login | Companion §16 (TPL-1..7, Appendix E rows E33, E34); initiative document, Solution 2 and Fit by business case |
| Appendix A | Companion Appendix A (open decisions) and Appendix E (protocol decisions) |

---

## Appendix C — Third-party-initiated login (alternative pattern)

This pattern is retained as an alternative for business cases in which an agency must interact with the person directly in its own service. It is not used for the Department of State case, which uses the STS (section 11). It is implemented in the three reference applications (America.gov initiator; OIDC and SAML agencies) so partners can see both patterns side by side; Login.gov itself needs no change for it.

Three things do not change under this pattern. **Billing:** the agency's sign-in is a direct sign-in to the agency and is billed to the agency exactly as one; America.gov is not billed for it. **Consent management:** the person sees Login.gov's existing consent screen for the agency's own attributes, as for any direct sign-in; nothing is delegated, so the delegated-access consent (sections 4 and 5) is not involved. **Logging and fraud signals:** the agency receives the Attempts API events of a direct sign-in, and both applications log the hand-off (start, return, status) with the correlation hint, which carries no identity.

Standard: https://openid.net/specs/openid-connect-core-1_0.html#ThirdPartyInitiatedLogin

### Objective

America.gov can send a signed-in person to an agency's own service, the agency signs the person in through Login.gov without asking for credentials again, and the person returns to America.gov, with no delegated token involved.

### Functional requirements

| ID | Requirement |
|---|---|
| **FR-TPL-1** | The pattern MUST follow OpenID Connect Core 1.0 section 4 (Initiating Login from a Third Party): America.gov sends the person's browser to the agency's published login-initiation address, identifying Login.gov as the identity provider and the page the person should land on. |
| **FR-TPL-2** | The agency MUST sign the person in through its own Login.gov integration, with its own assurance requirements, attribute agreement, consent screen, fraud-signal enrollment, and billing. Login.gov MUST treat this sign-in exactly as any direct sign-in to the agency. |
| **FR-TPL-3** | When the person has an active Login.gov session, Login.gov MUST NOT ask for credentials again unless the agency requires it or a higher assurance level requires further verification. |
| **FR-TPL-4** | The agency MUST refuse an initiation request unless `iss` names the Login.gov it is configured to use, and unless `target_link_uri` matches an allow-list of exact origins the agency approved (the two checks OpenID Connect Core §4 requires of the relying party: a forged `iss` would send the person to an attacker's identity provider, and an unchecked `target_link_uri` is an open redirect). |
| **FR-TPL-5** | America.gov MUST send `iss` (Login.gov), `login_hint` and `target_link_uri`. `login_hint` MUST be a correlation identifier America.gov generates for this hand-off (a UUID), recorded on its server, single-use, and short-lived (ten minutes in the reference). It MUST carry no identity. The agency MUST remember it for the sign-in it starts and MUST treat the Login.gov sign-in as the only proof of who the person is. When America.gov needs the agency to trust task context or a return address beyond the allow-listed origin, it SHOULD add a signed, single-use statement; the correlation hint alone is sufficient for the flow to be correct. |
| **FR-TPL-6** | When its sign-in completes, the agency MUST send the person to `target_link_uri` with the same `login_hint`, its own identifier as `iss` (client_id or SAML entityID), and `status` (`signed_in` or `failed`), and MUST clear the hand-off so it cannot be replayed. America.gov MUST accept a return only when `login_hint` matches a hand-off it issued and still has outstanding in the same browser session, so a result cannot be attached to a different person's session; `iss` and `status` from an unmatched return MUST be ignored. The return MUST carry no identity data. |
| **FR-TPL-7** | The person MUST be told, at the hand-off, that they are leaving America.gov and which agency they are going to, and MUST be able to return to America.gov when done. |
| **FR-TPL-8** | Nothing in this pattern MAY require America.gov to hold a token for the agency or to call the agency's systems directly. |
| **FR-TPL-9** | A SAML agency MUST complete the return from a page of its own (an immediate refresh plus a visible link) rather than an HTTP redirect from its assertion consumer. Login.gov's SAML POST-binding page carries a Content-Security-Policy `form-action` limited to Login.gov and the agency's consumer URL, and Chrome applies `form-action` to the redirects that follow a form submission, so a cross-origin redirect from the consumer is blocked and the person is left on Login.gov's page. An OIDC agency's callback is reached by a GET redirect and MAY redirect directly. (Found in the live end-to-end run.) |
| **FR-TPL-10** | The agency's sign-in MUST be billed to the agency as a direct sign-in and MUST deliver the agency's ordinary Attempts API events; America.gov MUST NOT be billed for it. Both applications MUST log the hand-off's start, return and status with the correlation hint and no identity data. |

### Questions to resolve

1. Who defines and maintains the hand-off and return formats: Login.gov (as a published profile all agencies follow), America.gov, or each agency? A single profile avoids each agency inventing its own.
2. Should the hand-off include a hint about who the person is (for example, a hash of their email) so the agency can warn if the person who signs in appears to be someone else? It cannot be a binding, because Login.gov gives each agency a different identifier for the same person.
3. Is the return to America.gov required, optional, or forbidden for a given business case?
4. Should the agency re-authenticate the person even when a Login.gov session exists, for high-consequence tasks?
5. What should the person experience if the hand-off fails (expired statement, agency unavailable): an error at the agency, or a return to America.gov with a message?
6. Login.gov's session ends after 15 minutes idle and 12 hours total. Is that short enough that a person handed off late in a session may be asked to sign in again, and is that acceptable?
7. Does Login.gov need any change for this pattern? None; the reference implementation runs against the unchanged identity provider. One operational note: with all reference applications on one host, each must use its own session cookie name, since browsers scope cookies by host and not port.

---

## Appendix D — Decisions log

### 2026-10-09 (interview on the first implementation feature, onboarding data model)

Decisions by the product owner, applied to the rows above and to the companion document (§3.4, §4.8, Appendix E rows E37–E45).

1. An **application** is the unit of consent: an agency's own record for one service, carrying consent content and owning one or more agency API URLs. A person can approve one application at an agency and not another. Rationale: people think in applications, not agencies. (FR-CUX-3, FR-CEN-1, terms.)
2. A service provider requests **one scope per application**; the application's APIs are listed for information and the specific API is chosen when the token is issued. (FR-CEN-1, FR-ONB-2.)
3. **Consent content is maintained in the partner Dashboard**, for the agency, each application and each service provider, so it can be updated regularly; every edit is versioned and marked material or not. The Dashboard change is a dependency on another repository; a seed path serves non-production environments until then. (FR-ONB-3, FR-ONB-9.)
4. **Advance approval from the account page is consent**: the page lists every registered application that accepts the service provider, grouped by agency; turning one on is a remembered approval for up to one year from that moment. (FR-CUX-12, FR-CUX-13, FR-CEN-11.)
5. **Requested applications are take-it-or-cancel**: shown selected and locked; declining means cancelling the sign-in. Reverses the earlier FR-CUX-4/5 and FR-CEN-6; there are no per-application declines to record. (FR-CUX-4, FR-CUX-5, FR-CEN-6, FR-CEN-17.)
6. The **remember choice stays** for approvals given on the consent screen, default not remembered (this sign-in only). (FR-CUX-7, FR-CEN-11.)
7. **Which service providers an application accepts** is a list on the application; empty means any service provider Login.gov approved for delegation. Service provider approval is on its own record. Neither lives in application configuration. (FR-ONB-2, FR-ONB-9, FR-CEN-2.)
8. An approval is recorded per **(person, service provider, application)**, with its source, time, remember period, content versions and revocation. (FR-CEN-17.)
9. **Only material content changes re-ask**; editorial changes do not. (FR-CEN-5, FR-CEN-8.)
10. **Agency-level content** (description, learn more) is stored with the agency, alongside its name and logo. (FR-ONB-3.)

**Still open:** whether the account page should also offer applications under service providers the person has never connected to; revision of the consent-screen mockup for locked rows (FR-CUX-11).
