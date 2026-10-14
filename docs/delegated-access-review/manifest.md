# Review and merge manifest

The stack starts on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. Runtime source provenance is the original fourteen PRs #13632–#13645 through `3121f14fe161c18cdb76c8c6f8cbc1e3ca301c82`; the document and site-key prerequisites are split out rather than inherited as an opaque foundation. Each commit credits Kyle Neuman, Tai Groot and SgtPluck. The publishing account is `dlh-woc`.

Review each PR against its immediate parent. Merge bottom-up using the repository's approved process; if a merge changes parent commit identities, restack the remaining PRs before merging the next one. These are draft review units, not independent feature releases. Shared definitions precede consumers; full-stack SAML scenarios live with the final compatibility coverage. The complete stack is the integration validation target.

| Order | Branch / PR | Review focus |
|---|---|---|
| 1 | [#13657 · dcl/delegated-access/review-guide](https://github.com/18F/identity-idp/pull/13657) | [Document the delegated-access review contract and reconstruction](changes/review-guide.md) |
| 2 | [#13658 · dcl/delegated-access/document-storage](https://github.com/18F/identity-idp/pull/13658) | [Read encrypted document artifacts](changes/document-storage.md) |
| 3 | [#13659 · dcl/delegated-access/document-artifacts](https://github.com/18F/identity-idp/pull/13659) | [Model shareable document artifacts](changes/document-artifacts.md) |
| 4 | [#13660 · dcl/delegated-access/document-capture](https://github.com/18F/identity-idp/pull/13660) | [Capture verified document artifacts](changes/document-capture.md) |
| 5 | [#13661 · dcl/delegated-access/document-consent](https://github.com/18F/identity-idp/pull/13661) | [Collect document-sharing consent](changes/document-consent.md) |
| 6 | [#13662 · dcl/delegated-access/document-release](https://github.com/18F/identity-idp/pull/13662) | [Release opted-in document images](changes/document-release.md) |
| 7 | [#13663 · dcl/delegated-access/site-key-crypto](https://github.com/18F/identity-idp/pull/13663) | [Add per-site key cryptographic primitives](changes/site-key-crypto.md) |
| 8 | [#13664 · dcl/delegated-access/site-key-custody](https://github.com/18F/identity-idp/pull/13664) | [Protect per-site key roots with user credentials](changes/site-key-custody.md) |
| 9 | [#13665 · dcl/delegated-access/site-key-browser](https://github.com/18F/identity-idp/pull/13665) | [Seal per-site keys to the requesting browser](changes/site-key-browser.md) |
| 10 | [#13666 · dcl/delegated-access/site-key-recovery](https://github.com/18F/identity-idp/pull/13666) | [Recover per-site keys after password reset](changes/site-key-recovery.md) |
| 11 | [#13667 · dcl/delegated-access/site-key-personal-key](https://github.com/18F/identity-idp/pull/13667) | [Recover per-site keys using a personal key](changes/site-key-personal-key.md) |
| 12 | [#13668 · dcl/delegated-access/dependency-security](https://github.com/18F/identity-idp/pull/13668) | [Update dependencies and secret-scanning exclusions](changes/dependency-security.md) |
| 13 | [#13669 · dcl/delegated-access/configuration-keys](https://github.com/18F/identity-idp/pull/13669) | [Declare delegated-access configuration and translations](changes/configuration-keys.md) |
| 14 | [#13670 · dcl/delegated-access/delegation-schema](https://github.com/18F/identity-idp/pull/13670) | [Create the final delegation and billing schema](changes/delegation-schema.md) |
| 15 | [#13671 · dcl/delegated-access/registry](https://github.com/18F/identity-idp/pull/13671) | [Register applications and service providers for delegation](changes/registry.md) |
| 16 | [#13672 · dcl/delegated-access/dpop-proofs](https://github.com/18F/identity-idp/pull/13672) | [Verify DPoP signatures and prevent proof replay](changes/dpop-proofs.md) |
| 17 | [#13673 · dcl/delegated-access/client-authentication](https://github.com/18F/identity-idp/pull/13673) | [Authenticate callers of delegated endpoints](changes/client-authentication.md) |
| 18 | [#13674 · dcl/delegated-access/token-state](https://github.com/18F/identity-idp/pull/13674) | [Store approvals and bounded delegated token families](changes/token-state.md) |
| 19 | [#13675 · dcl/delegated-access/fraud-event-catalog](https://github.com/18F/identity-idp/pull/13675) | [Document and verify delegated-access Attempts events](changes/fraud-event-catalog.md) |
| 20 | [#13676 · dcl/delegated-access/fraud-session-buffer](https://github.com/18F/identity-idp/pull/13676) | [Buffer delegated-session fraud signals securely](changes/fraud-session-buffer.md) |
| 21 | [#13677 · dcl/delegated-access/fraud-consent-release](https://github.com/18F/identity-idp/pull/13677) | [Release fraud signals only to approved agency recipients](changes/fraud-consent-release.md) |
| 22 | [#13678 · dcl/delegated-access/billing-evidence](https://github.com/18F/identity-idp/pull/13678) | [Record delegated billing as append-only evidence](changes/billing-evidence.md) |
| 23 | [#13679 · dcl/delegated-access/delegated-claims](https://github.com/18F/identity-idp/pull/13679) | [Build agency-scoped delegated identity claims](changes/delegated-claims.md) |
| 24 | [#13680 · dcl/delegated-access/saml-assertions](https://github.com/18F/identity-idp/pull/13680) | [Issue delegated SAML assertions with original authentication time](changes/saml-assertions.md) |
| 25 | [#13681 · dcl/delegated-access/consent-services](https://github.com/18F/identity-idp/pull/13681) | [Manage delegation approval and revocation](changes/consent-services.md) |
| 26 | [#13682 · dcl/delegated-access/authorization-binding](https://github.com/18F/identity-idp/pull/13682) | [Preserve compatibility while binding authorization transactions](changes/authorization-binding.md) |
| 27 | [#13683 · dcl/delegated-access/consent-screen](https://github.com/18F/identity-idp/pull/13683) | [Present application-specific delegation consent at sign-in](changes/consent-screen.md) |
| 28 | [#13684 · dcl/delegated-access/account-management](https://github.com/18F/identity-idp/pull/13684) | [Let users review and revoke delegated access](changes/account-management.md) |
| 29 | [#13685 · dcl/delegated-access/token-exchange](https://github.com/18F/identity-idp/pull/13685) | [Exchange approved sign-in tokens for agency access](changes/token-exchange.md) |
| 30 | [#13686 · dcl/delegated-access/token-refresh](https://github.com/18F/identity-idp/pull/13686) | [Rotate refresh tokens without weakening family security](changes/token-refresh.md) |
| 31 | [#13687 · dcl/delegated-access/token-introspection](https://github.com/18F/identity-idp/pull/13687) | [Verify delegated tokens against current authorization and revocation](changes/token-introspection.md) |
| 32 | [#13688 · dcl/delegated-access/token-revocation](https://github.com/18F/identity-idp/pull/13688) | [Revoke one token or its entire refresh family](changes/token-revocation.md) |
| 33 | [#13689 · dcl/delegated-access/endpoint-wiring](https://github.com/18F/identity-idp/pull/13689) | [Wire delegated endpoints with compatible disabled behavior](changes/endpoint-wiring.md) |
| 34 | [#13690 · dcl/delegated-access/billing-reports](https://github.com/18F/identity-idp/pull/13690) | [Report delegated usage without changing disabled report shapes](changes/billing-reports.md) |
| 35 | [#13691 · dcl/delegated-access/registry-seeding](https://github.com/18F/identity-idp/pull/13691) | [Seed delegation content from environment configuration](changes/registry-seeding.md) |
| 36 | [#13692 · dcl/delegated-access/encrypted-userinfo](https://github.com/18F/identity-idp/pull/13692) | [Encrypt userinfo for opted-in confidential service providers](changes/encrypted-userinfo.md) |
| 37 | [#13693 · dcl/delegated-access/compatibility-coverage](https://github.com/18F/identity-idp/pull/13693) | [Verify disabled features and rollback across the complete flow](changes/compatibility-coverage.md) |
| 38 | [dcl/delegated-access/review-record](https://github.com/18F/identity-idp/tree/dcl/delegated-access/review-record) | Requirements, provenance, data review and measured verification. |

## Review priorities

First read the [compatibility contract](README.md), then the [data review](data-review.md) and [verification record](verification.md). Focus on false flags, legacy/null client settings, in-flight authorization state, stored bindings through rollback, family revocation races, current allowlists and immutable authentication time. Keep source Appendix D's unresolved billing and operational questions visible.

The original PRs are preserved as provenance. This stack does not merge them, close them, change repository protection, or claim external reference applications were deployed. Agent-specific duplicate indexes and workflow metadata were omitted; the runtime file comparison against the corrected integration snapshot was exact. Changelogs travel with every review unit rather than living only on a remote foundation branch.
