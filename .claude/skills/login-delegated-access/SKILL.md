---
name: login-delegated-access
description: Use for any question, review, edit, run or decision about the delegated-access branches of identity-idp (login-delegated-access and the delegated-access-* stack), their requirements (FR rows, protocol rows, decisions), the RFCs they implement, the local stack or the branch stack.
---

# Login.gov delegated access (identity-idp)

## 1. What this is and the rules

- One authoritative document, `docs/delegated-access-functional-requirements.md`: sections 1 to 14, one per feature
  branch in stack order, each with Objective, How it works (diagram, sample requests and responses), Functional requirements (`FR-…` rows), Protocol rows (`ONB-`, `CON-`,
  `ACC-`, `EXC-`, `REF-`, `INT-`, `SAML-`, `DISC-`, `BIL-`, `ATT-`, `UINF-`), As built, Decisions and How to review;
  section 15 the base branch and work outside this repository; section 16 the decisions log (`Dnn`); Appendix A the
  generated traceability matrix; Appendices B to F the stack and review procedure, environment-specific pieces, the
  performance review and open items, the foundation, terms. `docs/delegated-access-README.md` says how to read it.
- The document lives only on `login-delegated-access`. Fourteen code-only feature branches are stacked on it (section 6).
- `CLAUDE.md` governs every change (vocabulary, fictitious names, no requirement ids in code, local before CI).
  This skill adds context and rationale; it never overrides `CLAUDE.md` and never vetoes a change. Requirements
  can change; the developer decides.
- Public repository: nothing in the skill or the docs may carry secrets, internal hostnames, personal paths or real
  agency names.

## 2. Start here (every invocation)

1. Run `python3 .claude/skills/login-delegated-access/scripts/build_index.py --check`.
2. If it reports stale output, run the same command without `--check`, tell the developer that the generated
   references (and Appendix A of the document) were regenerated, and continue.
3. Pick the activity below and load only the references it names. Paths are relative to this skill's directory.

## 3. Activity → references

| Activity | Load, in this order |
|---|---|
| Question about a requirement (what does FR-X / EXC-n say, who implements it) | `references/requirements-index.md`, then the cited section of the document (line numbers are in the index) |
| Which branch, what it changes, why | `references/branches.md`, `references/branch-context/<branch>.md`, `references/traceability.md` |
| Why is it built this way | `references/decisions.md` → the section 16 entry, `references/foundation-sbx-taigrr.md` (what the foundation branch already provided) |
| Protocol question (OAuth, token exchange, DPoP, introspection, SAML) | `references/rfcs/README.md` → the RFC digest; fetch the full text from rfc-editor.org when the digest is not enough |
| Review a branch | `references/branch-context/<branch>.md`, the branch's section of the document (How to review), the diff against the branch below it (`git diff <below>..<branch>`), `references/traceability.md` for the rows it must satisfy |
| Edit code or change a requirement | `references/update-protocol.md` and `references/interview.md` FIRST, then the activity rows above as needed |
| Run locally, what is local-only, sandbox | `references/local-runbook.md`, `scripts/local_stack.sh`, `references/local-only-changes.md`, `scripts/local_only_changes.sh`, `references/sandbox-notes.md` |
| Billing change (`sp_return_logs`, waiver, adjustments, reports) | `.claude/skills/login-billing/SKILL.md` first, then `references/branch-context/delegated-access-billing-reporting.md` |
| Schema, log, token-storage, analytics or Attempts-schema change | `.claude/skills/login-billing/SKILL.md` section 9 and its `references/data-change-review-guidelines.md` (data team review and notification) |
| Rebase or merge the base into a feature branch with conflicts in the skill or the document | `references/conflict-resolution.md`, `scripts/skill_conflicts.sh` (feature context wins for its own work; base wins elsewhere; generated and twin files are regenerated, never hand-resolved) |
| Open, review or merge the stacked pull requests; branch protection | `references/review-and-merge.md` (stacked bases, review-time rules, bottom-up fast-forward merge, the ruleset to request) |
| Where to start reading | `references/reading-order.md` |

## 4. Changing things

1. Before any edit to code or to a requirement, run the interview: invoke `/interview` when available, otherwise
   follow `references/interview.md`. Keep it short when the change is small; cover every question area when it is not.
2. State an informed opinion: does the change make sense given the design and the recorded rationale
   (`references/decisions.md`, section 16 of the document, the RFC digests)? Say what it conflicts with, if anything,
   and what it costs. Then do what the developer decides.
3. Collect the rationale when it is not obvious (why, and what was rejected) so the decision entry can carry it.
4. Record the outcome per `references/update-protocol.md` in the same unit of work: a new dated entry in section 16
   (next D-number), the owning section's FR and protocol rows amended in place to their current state (no trails),
   its Decisions list and As built updated when code lands, then regenerate Appendix A and the indexes with
   `build_index.py`.
5. Notify the developer explicitly, in the reply, whenever a change alters a requirement or alters the skill's
   context (a document section, a branch's scope, a generated reference).

## 5. Keeping the skill current

- After any change to the document: `python3 .claude/skills/login-delegated-access/scripts/build_index.py`.
- After any change under `.claude/skills/`: `.claude/skills/login-delegated-access/scripts/sync_twins.sh`
  (`.agents/skills` must stay byte-identical; `--check` verifies).
- `bash .claude/skills/login-delegated-access/scripts/check.sh` runs every check (indexes current, twins identical,
  headers present, markers paired, size limit). There is deliberately no test in the repository's suite for this.
- Never edit a generated file by hand: `requirements-index.md`, `traceability.md`, `branches.md`, `decisions.md`
  and the Appendix A body between the markers in the document.
- Hand-written references (`foundation.yml`, `foundation-sbx-taigrr.md`, `branch-context/`, `rfcs/`, runbooks)
  are edited directly, then the twins are synced.

## 6. Branch stack in one glance

Appendix B of the document is authoritative; review each branch as the diff against the one below it. The
number is the branch's section in the document.

```
login-delegated-access                      base: the document, CLAUDE.md, AGENTS.md, this skill
 ├─  1. delegated-access-registry           section 1   onboarding data model and registry
 ├─  2. delegated-access-consent            section 2   authorize request and consent screen
 ├─  3. delegated-access-account-page       section 3   Account → Delegated access
 ├─  4. delegated-access-site-keys          section 4   per-site keys (ported)
 ├─  5. delegated-access-dpop               section 5   public-client key binding (DPoP)
 ├─  6. delegated-access-token-exchange     section 6   RFC 8693 exchange at the token endpoint
 ├─  7. delegated-access-token-lifecycle    section 7   refresh rotation, revocation, suspension
 ├─  8. delegated-access-introspection      section 8   RFC 7662 introspection
 ├─  9. delegated-access-saml-assertions    section 9   SAML assertions as an issued token type
 ├─ 10. delegated-access-operations         section 10  discovery and operational metadata
 ├─ 11. delegated-access-billing-reporting  section 11  billing rows and reports
 ├─ 12. delegated-access-fraud-signals      section 12  Attempts API fraud signals
 ├─ 13. delegated-access-config-content     section 13  content seeded from identity-idp-config
 └─ 14. delegated-access-encrypted-userinfo section 14  encrypted userinfo responses
```

Not branches (section 15): document-image sharing stays on the base, enabled only in a sandbox (15.1);
third-party-initiated login lives in the reference applications (15.2); the account-page history view is planned
(15.5); delegated tokens at the user-information endpoint are documented and not built (15.6).
