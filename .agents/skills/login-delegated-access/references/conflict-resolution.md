# Resolving conflicts in the skill and the documents when the base meets a feature branch

The documents under `docs/` and this skill live on `login-delegated-access` (the base). Feature
branches are stacked on it and are meant to be code-only, so the normal case has no conflict here.
When a feature branch does carry skill or document edits (a developer recorded context while
working on it) and the base is brought into that branch, by `git rebase` or by `git merge`, apply
the rules below. They need some inference; the helper `scripts/skill_conflicts.sh` does the
mechanical part and lays out the evidence for the rest.

## The rule

1. **Context the feature branch added about its own work wins** over older skill or document
   content from the base: a new or amended branch-context section, a decision the branch recorded,
   an as-built fact, a runbook step that the branch's code made true.
2. **For every other conflict the base is authoritative**: shared rules and conventions, the
   update protocol, the interview, reading order, RFC digests, generated files, and any content
   about branches other than the one being rebased.
3. **Generated files are never hand-resolved.** Take the base side and regenerate.
4. **Twins are never hand-resolved.** Take the base side and run the twin sync.

## Procedure

1. Note the direction. In `git rebase`, "ours" is the branch being rebased ONTO (the base) and
   "theirs" is the commit being replayed (the feature branch). In `git merge`, it is the reverse.
   The helper prints both labels so the sides are never confused.
2. Run `bash .claude/skills/login-delegated-access/scripts/skill_conflicts.sh` from the repository
   root while the conflict is open. It lists every conflicting path classified as `generated`,
   `twin`, `authored`, or `docs`, and for `authored` and `docs` paths shows three things:
   the feature branch's own commits that touched the path, the hunks the feature branch added
   since the merge base, and the hunks the base added since the merge base.
3. Let it resolve the mechanical classes: `--resolve-mechanical` takes the base side for
   `generated` and `twin` paths and marks them resolved (regeneration happens in step 6).
4. For each `authored` or `docs` path, start from the base version and re-apply only the feature
   branch's hunks that pass this test: the hunk states something about the feature branch's own
   code or decisions (it names a class, migration, route, config key or decision that the
   branch's code commits introduced or changed, or it is in that branch's `branch-context` file
   or the plan section for that feature). A hunk that edits shared guidance, another branch's
   context, or text the base has since amended with a later date or a higher decision number is
   dropped; the base wins.
5. When both sides amended the same fact, prefer the later dated amendment or the higher
   `Dnn` regardless of side; when there is no date or number to compare, the base wins and the
   feature branch's wording is carried as a note for the developer to confirm.
6. Regenerate and sync: `python3 .claude/skills/login-delegated-access/scripts/build_index.py`,
   then `bash .claude/skills/login-delegated-access/scripts/sync_twins.sh`, then
   `bash .claude/skills/login-delegated-access/scripts/check.sh`. Only then `git add` and continue
   the rebase or complete the merge.
7. Tell the developer, in the reply, every hunk that was kept from the feature branch and every
   one that was dropped, with the reason from step 4 or 5. These are judgment calls and they are
   reviewable.
8. Afterwards, move the feature branch's document and skill context to the base as its own
   documentation commit, so the stack returns to code-only feature branches and the next rebase
   has nothing to resolve here.

## Inference signals, in order of weight

- The feature branch's code commits (subjects carry FR identifiers; `git log <merge-base>..HEAD
  -- app lib db config`) and the files they touch. A skill hunk that names those classes, files,
  routes or keys is the branch's own context.
- Dated "Amended <date>" or "As built, <date>" lines and decision numbers: newer beats older.
- Placement: a hunk inside `references/branch-context/<this branch>.md` or inside the plan
  subsection for this feature is presumed to be the branch's context; a hunk inside shared files
  (`update-protocol.md`, `interview.md`, `reading-order.md`, `rfcs/`, `SKILL.md`, CLAUDE.md) is
  presumed shared guidance and the base wins unless the hunk is clearly a fact about this branch.
- A hunk whose feature-branch side equals the merge-base text is not a change by the branch at
  all; git resolves it, and if it is shown it is dropped.
