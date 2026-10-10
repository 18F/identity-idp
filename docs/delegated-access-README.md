# Delegated access: the documents, the branches and the skill

Delegated access lets an approved service provider, after the person consents on Login.gov, obtain a
short-lived token to call an agency's API on that person's behalf. The work is described by three documents
in this directory and built on a stack of code-only feature branches. This README says what each document
provides, how they relate, where to start, and how the branches and the skill cross-reference them.

## The three documents

| Document | Provides | Identifiers |
|---|---|---|
| `delegated-access-functional-requirements.md` | What the capability must do, area by area, for the product owner, reviewers and partners; open questions per area; the decisions taken (Appendix D) | `FR-<area>-<n>` rows (ONB onboarding, CUX consent experience, CEN consent enforcement, TOK tokens, VER verification, FRD fraud signals, BIL billing, OPS operations, DOS Department of State case, KEY per-site keys, TPL and FIT for the alternative pattern) |
| `delegated-access-requirements.md` (the companion) | How it is built, protocol by protocol, for maintainers: each row with Why, Where and How, code sketches, tables, configuration keys, test and rollout requirements, the reference applications and harness; dated amendment subsections; protocol decisions (Appendix E) | `ONB-`, `CON-`, `ACC-`, `EXC-`, `INT-`, `REF-`, `ATT-`, `BIL-`, `DISC-`, `SAML-`, `TPL-` rows; `Ennn` decisions |
| `delegated-access-implementation-plan.md` (the plan) | What the foundation branch (`sbx-taigrr`) already had, what each feature adds and removes and why, findings for engineering decisions, as-built records, the branch stack and review order (section 8), the decisions log (section 9), environment-specific pieces (7.5) | Features `5.x`; decisions `Dnn` |

How they relate: the FR document states intent; the companion states the design that meets it; the plan
states how the design was realized on the foundation, feature by feature, and records every decision that
changed either of the other two. Each plan feature's "**Requirements**" line names the FR rows and companion
rows it serves; the plan's section 8 table names the branch. A decision is recorded three times on the same
day: `Dnn` in plan section 9 (with rationale and the rejected alternative), the matching item in FR Appendix D,
and an `Ennn` row in companion Appendix E, with the affected rows amended in place. `CLAUDE.md` section 1
gives the rules; the skill's `references/update-protocol.md` gives the steps.

## Reading order

- **For the shape of the thing**: this README; FR document sections 1–2 and the Objective of each area;
  companion sections 0–2 (terms, actors, happy path, design decisions); plan sections 1, 3 and 4; then the
  branch diagram below.
- **To review one branch**: plan section 8 "Where to start", the feature's 5.x section, the FR and companion
  rows its Requirements line names, then the diff against the branch below it.
- **To change something**: `CLAUDE.md`, the owning feature's 5.x section and its decisions in plan section 9,
  the companion rows for the protocol detail, the RFC; then the skill's interview and update protocol.
- **For one identifier**: the skill's `references/requirements-index.md` gives document, section and line.

## The branch stack

Thirteen code-only branches, each starting from the previous one's tip; `login-delegated-access` carries
the base and the documents. Review each branch as the diff against the one below it; acceptance is a
fast-forward of the base, bottom to top (plan section 8).

```
login-delegated-access                      base: main merge, docs, CLAUDE.md / AGENTS.md, the skill
 ├─  1. delegated-access-registry           §5.1  onboarding data model and registry
 ├─  2. delegated-access-consent            §5.2  authorize request and consent screen
 ├─  3. delegated-access-account-page       §5.3  Account → Delegated access
 ├─  4. delegated-access-site-keys          §5.16 per-site keys (ported)
 ├─  5. delegated-access-dpop               §5.10 public-client key binding (DPoP)
 ├─  6. delegated-access-token-exchange     §5.4  RFC 8693 exchange at the token endpoint
 ├─  7. delegated-access-token-lifecycle    §5.5  refresh rotation, revocation, suspension
 ├─  8. delegated-access-introspection      §5.6  RFC 7662 introspection
 ├─  9. delegated-access-saml-assertions    §5.9  SAML assertions as an issued token type
 ├─ 10. delegated-access-operations         §5.11 discovery and operational metadata
 ├─ 11. delegated-access-billing-reporting  §5.8  billing rows and reports
 ├─ 12. delegated-access-fraud-signals      §5.7  Attempts API fraud signals
 └─ 13. delegated-access-config-content     §5.17 content seeded from identity-idp-config
```

Not branches: 5.12 (document images) is foundation code kept on the base and enabled only in a sandbox;
5.13 (third-party-initiated login) lives in the reference applications; 5.14 and 5.15 are planned.

## The traceability matrices

Each document carries a generated matrix that shows the same join from its own side:

- plan **8.1 Traceability matrix**: branch → plan section → FR rows → companion rows → foundation items;
- FR document **Appendix E — Traceability matrix**: FR row → companion rows → plan section → branch;
- companion **Appendix F — Traceability matrix**: row group → FR rows → plan section → branch.

Only the body between the `<!-- traceability:begin -->` and `<!-- traceability:end -->` markers is
generated, by `.claude/skills/login-delegated-access/scripts/build_index.py`, from the plan's 5.x
Requirements lines, its section 8 table, the FR document's Appendix B and the skill's `references/foundation.yml`.
The same run writes the skill's `requirements-index.md` (every identifier with document, section and line),
`traceability.md`, `branches.md` (the stack as git sees it) and `decisions.md`. Edit the documents, never
the matrices; rerun the generator after any docs change (`--check` reports staleness without writing).

## Where the foundation's contributions are recorded

The pieces that `sbx-taigrr` already satisfied before this work (grant tables, consent screen shape, agency
opt-in, document-image sharing, analytics) are described in plan sections 3.1 and 3.4 and, per feature, in
each 5.x "What `sbx-taigrr` has" paragraph. The skill records them as items in `references/foundation.yml`
(with the FR rows each satisfies) and explains them in `references/foundation-sbx-taigrr.md`; the generator
lists them in the foundation column of the plan 8.1 and FR Appendix E matrices.

## The skill

`.claude/skills/login-delegated-access` is a project skill for agents and people working on these branches.
`SKILL.md` is short: the rules, a start-up check, and a table that maps each activity (requirement question,
branch review, protocol question, code or requirement change, running the local stack) to the one or two
references to load, so a session reads only what it needs. `references/` holds the generated indexes, the
per-branch context, RFC digests, the interview and update protocol, and the local and sandbox runbooks;
`scripts/` holds the generator, the twin sync and the local stack helpers. `.agents/skills` is a
byte-identical twin kept by `scripts/sync_twins.sh` and checked by the skill's own `scripts/check.sh` (nothing is added to the repository's test suite). In Claude
Code the skill loads when the conversation concerns these branches, or on request with
`/login-delegated-access`; `/interview` runs the interview that precedes every change.
