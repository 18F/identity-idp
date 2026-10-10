---
name: login-delegated-access
description: Use for any question, review, edit, run or decision about the delegated-access branches of identity-idp (login-delegated-access and the delegated-access-* stack), their requirements (FR rows, companion rows, decisions), the RFCs they implement, the local stack or the branch stack.
---

# Login.gov delegated access (identity-idp)

## 1. What this is and the rules

- Three authoritative documents under `docs/`: the implementation plan (`delegated-access-implementation-plan.md`,
  features 5.x, branch map in section 8, decisions `Dnn` in section 9), the functional requirements
  (`delegated-access-functional-requirements.md`, `FR-…` rows, Appendix D) and the companion requirements
  (`delegated-access-requirements.md`, protocol rows `ONB-`, `CON-`, `ACC-`, `EXC-`, `INT-`, `REF-`, `ATT-`, `BIL-`,
  `DISC-`, `SAML-`, `TPL-`, Appendix E rows `Ennn`). `docs/delegated-access-README.md` says how they relate.
- The documents live only on `login-delegated-access`. Thirteen code-only feature branches are stacked on it (section 6).
- `CLAUDE.md` governs every change (vocabulary, fictitious names, no requirement ids in code, local before CI).
  This skill adds context and rationale; it never overrides `CLAUDE.md` and never vetoes a change. Requirements
  can change; the developer decides.
- Public repository: nothing in the skill or the docs may carry secrets, internal hostnames, personal paths or real
  agency names.

## 2. Start here (every invocation)

1. Run `python3 .claude/skills/login-delegated-access/scripts/build_index.py --check`.
2. If it reports stale output, run the same command without `--check`, tell the developer that the generated
   references (and any document matrix) were regenerated, and continue.
3. Pick the activity below and load only the references it names. Paths are relative to this skill's directory.

## 3. Activity → references

| Activity | Load, in this order |
|---|---|
| Question about a requirement (what does FR-X / EXC-n say, who implements it) | `references/requirements-index.md`, then the cited document section (line numbers are in the index) |
| Which branch, what it changes, why | `references/branches.md`, `references/branch-context/<branch>.md`, `references/traceability.md` |
| Why is it built this way | `references/decisions.md` → plan section 9 entry, `references/foundation-sbx-taigrr.md` (what the foundation branch already provided) |
| Protocol question (OAuth, token exchange, DPoP, introspection, SAML) | `references/rfcs/README.md` → the RFC digest; fetch the full text from rfc-editor.org when the digest is not enough |
| Review a branch | `references/branch-context/<branch>.md`, the diff against the branch below it (`git diff <below>..<branch>`), `references/traceability.md` for the rows it must satisfy |
| Edit code or change a requirement | `references/update-protocol.md` and `references/interview.md` FIRST, then the activity rows above as needed |
| Run locally, what is local-only, sandbox | `references/local-runbook.md`, `scripts/local_stack.sh`, `references/local-only-changes.md`, `scripts/local_only_changes.sh`, `references/sandbox-notes.md` |
| Billing change (`sp_return_logs`, waiver, adjustments, reports) | `.claude/skills/login-billing/SKILL.md` first, then `references/branch-context/delegated-access-billing-reporting.md` |
| Schema, log, token-storage, analytics or Attempts-schema change | `.claude/skills/login-billing/SKILL.md` section 9 and its `references/data-change-review-guidelines.md` (data team review and notification) |
| Where to start reading | `references/reading-order.md` |

## 4. Changing things

1. Before any edit to code or to a requirement, run the interview: invoke `/interview` when available, otherwise
   follow `references/interview.md`. Keep it short when the change is small; cover every question area when it is not.
2. State an informed opinion: does the change make sense given the design and the recorded rationale
   (`references/decisions.md`, plan section 9, the RFC digests)? Say what it conflicts with, if anything, and what
   it costs. Then do what the developer decides.
3. Collect the rationale when it is not obvious (why, and what was rejected) so the decision entry can carry it.
4. Record the outcome per `references/update-protocol.md` in the same unit of work: decision log entry (next
   D-number) in plan section 9, FR Appendix D item, amended FR rows, companion amendment rows and Appendix E row,
   as-built blocks when code lands, then regenerate the indexes and the README matrices with `build_index.py`.
5. Notify the developer explicitly, in the reply, whenever a change alters a requirement or alters the skill's
   context (a document section, a branch's scope, a generated reference).

## 5. Keeping the skill current

- After any change under `docs/`: `python3 .claude/skills/login-delegated-access/scripts/build_index.py`.
- After any change under `.claude/skills/`: `.claude/skills/login-delegated-access/scripts/sync_twins.sh`
  (`.agents/skills` must stay byte-identical; `--check` verifies).
- `bash .claude/skills/login-delegated-access/scripts/check.sh` runs every check (indexes current, twins identical,
  headers present, markers paired, size limit). There is deliberately no test in the repository's suite for this.
- Never edit a generated file by hand: `requirements-index.md`, `traceability.md`, `branches.md`, `decisions.md`
  and the marked matrix bodies in the three documents (plan 8.1, FR Appendix E, companion Appendix F).
- Hand-written references (`foundation.yml`, `foundation-sbx-taigrr.md`, `branch-context/`, `rfcs/`, runbooks)
  are edited directly, then the twins are synced.

## 6. Branch stack in one glance

Plan section 8 is authoritative; review each branch as the diff against the one below it.

```
login-delegated-access                      base: docs, CLAUDE.md, AGENTS.md, this skill
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

Not branches: 5.12 (document images) stays on the base, enabled only in a sandbox; 5.13 lives in the reference
applications; 5.14 and 5.15 are planned.
