# Update protocol: recording a decision or an as-built change

This mirrors `CLAUDE.md` section 1 ("Keep it current, in the same unit of work as the code") and adds the
skill's own steps. Follow it for every change to a requirement and every code change the document no
longer describes. The document lives only on `login-delegated-access`; feature branches never commit under
`docs/`.

## Conflicts when the base meets a feature branch

Follow `conflict-resolution.md` with `scripts/skill_conflicts.sh`: the feature branch's own context wins, the
base wins elsewhere, generated files and twins are regenerated. Afterwards move the branch's document and
skill context to the base so feature branches return to code-only.

## 0. Before the edit

1. Run the interview (`references/interview.md`, or `/interview` when available). Keep it proportionate.
2. State the informed opinion, then collect rationale (sections 4 and 5 below).
3. Identify the owning section and branch (Appendix A; `references/branches.md`) and every row the change
   touches (`references/requirements-index.md`, `references/traceability.md`).

## 1. A requirement changes

Trigger: the product owner decides something, an interview resolves a question, a reviewer's recommendation
is accepted. Record it the same day, before or with the code. All of the following, in one docs commit on
`login-delegated-access`:

1. **Section 16, the decisions log.** Add a dated `##` subsection if none exists for today's context, then a
   numbered entry `**Dnn — Title.**` using the next free D-number (`references/decisions.md` lists them; the log
   is numbered across subsections). State the decision, the rationale, the rejected alternative, and in
   parentheses the FR and protocol rows it affects. If it replaces an earlier decision, say so in the new entry;
   the earlier entry is left as written.
2. **The owning section's rows.** Rewrite each affected `FR-…` and protocol row in place to its current state,
   citing the decision as `(Dnn)` at the end of the row. Add a row when the decision creates a requirement
   (next free number in that prefix) and delete a row when it removes one; a row another section owns is cited
   by identifier, never copied. No amendment trails, no struck text, no dated "Amended" or "Implemented"
   paragraphs: the history is in git and in section 16.
3. **The owning section's Decisions list.** Add one line, `- **Dnn** <gist>`, in D-number order.
4. **Objective and How to review** of the owning section when the decision changes what the branch delivers,
   what a reviewer must check first, or an open item. Resolve and remove `(note: …)` lines.
5. **Section 15 and the appendices** when the decision touches them: a design recorded and not built goes in
   section 15; a new local-only piece goes in the Appendix C table; a new or closed open item in Appendix D.2
   (items keep their numbers because section 16 cites them).
6. **Regenerate**: `python3 .claude/skills/login-delegated-access/scripts/build_index.py`. It rewrites the four
   generated references and the Appendix A body of the document.

## 2. Code lands or changes in a way the document no longer describes

1. **The owning section's As built list**: add or rewrite the numbered items naming classes, routes,
   migrations, config keys, analytics events, locale keys and specs with exact verification counts (examples
   run, lint results). Record deviations from the earlier text as decisions (section 1), never silently.
2. **How to review** of the same section: the specs that prove it, what must not change for existing clients,
   the open items held until the harness run.
3. **Appendix C**: add any new local-only or sandbox-only piece (and `references/local-only-changes.md`).
4. Regenerate as above.

## 3. The skill's own context

When a change alters a branch's scope, a document section the skill cites, or the stack order:

1. Hand-written references change by hand: `references/branch-context/<branch>.md`,
   `references/foundation.yml` (when a foundation item is superseded), `references/local-runbook.md`,
   `references/local-only-changes.md`, `references/sandbox-notes.md`, `references/rfcs/*.md`.
2. Generated references change only through `build_index.py`.
3. `SKILL.md` section 6 and `docs/delegated-access-README.md` carry the branch diagram; update both when
   the stack changes (the document's section headings and Appendix B are the source).
4. Run `.claude/skills/login-delegated-access/scripts/sync_twins.sh`, then
   `bash .claude/skills/login-delegated-access/scripts/check.sh`.

## 4. The informed opinion

Say it in one short paragraph before any edit, in this shape:

- what the change is, in the document's vocabulary (service provider, application, resource server);
- which decision or row it agrees with or conflicts with (cite `Dnn`, `FR-…`, the protocol row, the RFC
  section);
- the cost or risk the recorded rationale warns about (existing-client behavior, security posture, data
  growth, billing or fraud-signal effects, rebase cascade; for billing changes also load
  `.claude/skills/login-billing/SKILL.md`; for any schema, durable-log, token-storage, analytics or
  Attempts-schema change apply the data team's review in that skill's section 9 and
  `references/data-change-review-guidelines.md`, and notify the data team);
- the recommendation, stated plainly ("I would do it", "I would not, because …", "either works; the
  difference is …").

Then do what the developer decides. The opinion informs; it never blocks. If the developer decides against
the recommendation, record their rationale, not the recommendation.

## 5. Collecting and recording rationale

When the reason is not obvious from the conversation, ask for it in one question: "What makes this the
right call, and what did you consider instead?" Record the answer verbatim where possible as the
"Rationale:" and "Rejected:" clauses of the D-number entry. If the developer declines to give one, write
"Rationale: developer decision, <date>; alternative not recorded" so the gap is visible.

## 6. Notifying

In the reply that completes the work, state explicitly:

- "This changes requirement(s) <ids>" with the D-number recorded, when a row changed;
- "This changes the skill's context: <what>" when a reference, Appendix A or a branch scope changed;
- the generator summary line and whether `--check` passes;
- which branch the code commit belongs to and which branches above it need a rebase.

## 7. Commits and pushes

- Docs changes (the document, the README, the skill, `CLAUDE.md`/`AGENTS.md`) are committed on
  `login-delegated-access` only. Code is committed on the branch that owns the behavior (Appendix A gives the
  section and branch of every row); branches above it rebase in stack order (`git rebase <previous tip>` in
  each worktree, or `git rebase --update-refs` from the top).
- Commit subjects for code mirror the FR identifiers (`FR-TOK-1, FR-TOK-3: …`); bodies may cite protocol
  rows. Docs commit subjects name the decision (`D88: …`) or the As built change. No attribution trailers.
- Local before CI (`CLAUDE.md` section 4): touched specs, `spec/i18n_spec.rb`, rubocop on changed files, the
  analytics and tracker lints; the full suite on the top of the stack before pushing a branch.
- Before any push: `gitleaks git --redact --log-opts="<base>..HEAD" .` on the commit range and
  `gitleaks dir .` on the tree; report the result with the push. Push docs commits on the base at once;
  push feature branches only after they run locally. Never push to the GitLab mirrors.
