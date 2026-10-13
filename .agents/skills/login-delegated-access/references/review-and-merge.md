# Reviewing and merging the stack once pull requests are open

The fourteen feature branches are reviewed as stacked pull requests on GitHub and accepted into
`login-delegated-access` bottom-up by fast-forward. These rules keep the stack linear while
other people are reviewing. Repository facts they rest on (checked 2026-10-13): merge commits
and squash merges are enabled, rebase-merge is disabled, merged head branches are deleted
automatically, and since 2026-10-13 the ruleset "login-delegated-access base" applies to
`login-delegated-access`: pull request with two approving reviews required, linear history
required, force pushes and deletions blocked, no bypass actors yet. Until a bypass actor is added,
nothing is pushed straight to the base: documentation changes travel as a pull request from a
short-lived branch, and the fast-forward acceptance below waits for the bypass.

## Opening the pull requests

- One pull request per feature branch, with its **base set to the branch directly below it**
  (registry → `login-delegated-access`, consent → registry, …). Each pull request then shows
  only its own branch's commits.
- The description is the branch's `references/branch-context/<branch>.md` (purpose,
  requirements, decisions, key files, how to review, open items) plus one line:
  "Stacked on #N; merge position K of 14; do not use the merge button (see merge procedure)".
- A pinned tracking issue lists the fourteen pull requests in merge order with their status.

## While a pull request is under review

- Address comments with **new commits on the owning branch**. No fixups, no amends, no
  rebases of that branch: reviewers must be able to read only what changed since their review.
- A fix on a lower branch does not need to be propagated immediately; the pull requests above
  simply fall behind their base, and their own diffs are unchanged.
- Propagate in **announced sync waves**: one `git rebase --update-refs` from the top (or the
  stack helper), `git push --force-with-lease` on every rewritten branch, then post
  `git range-diff <old>...<new>` in each affected pull request so reviewers see that only the
  expected hunks moved. Batch waves per review round, not per commit.
- Skill or document conflicts during a wave follow `conflict-resolution.md`.

## Merging

- Merge **bottom-up, one pull request at a time**, when it is approved and the full suite is
  green on the stack top. The merging maintainer fast-forwards from the command line:
  `git push github <branch>:login-delegated-access`. GitHub marks the pull request merged
  because its head commits are now in the base; no new commit is created.
- **Never use the merge button.** A merge commit or a squash creates commits the branches above
  do not contain; every pull request above would then show duplicated changes and conflict.
- Let GitHub delete the merged head branch (or delete it). When a pull request's base branch is
  deleted, GitHub retargets the child pull request to that branch's base, so the next pull
  request moves to `login-delegated-access` on its own. Local worktrees are unaffected.
- After each merge, `delegated-access-integration` still names the top; nothing else moves.

## Branch protection, as applied and what is still missing

The admins applied a ruleset on `login-delegated-access` on 2026-10-13: pull request required
(two approving reviews), linear history required, force pushes and deletions blocked, no bypass
actors. Two things remain to request:

- a bypass actor on that ruleset (a team holding the merging maintainer, or the `maintain`
  repository role; individual users cannot be bypass actors), bypass mode "always". Without it
  the maintainer cannot fast-forward the base, GitHub's merge button could only squash (merge
  commits are blocked, rebase-merge is disabled), and a squash would put every pull request
  above into conflict. Documentation commits also need it to land without a two-review pull request;
- a second ruleset on `delegated-access-*`: block deletions; block force pushes for everyone
  except the maintainer (sync waves need them). No required status checks: this repository's
  continuous integration runs on GitLab through the mirror and reports no GitHub status.

The JSON is the base ruleset as it should read once the bypass actor is added:

```json
{
  "name": "login-delegated-access base",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/login-delegated-access"], "exclude": [] } },
  "rules": [
    { "type": "pull_request", "parameters": { "required_approving_review_count": 1, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } },
    { "type": "required_linear_history" },
    { "type": "non_fast_forward" },
    { "type": "deletion" }
  ],
  "bypass_actors": [ { "actor_id": 0, "actor_type": "RepositoryRole", "bypass_mode": "always" } ]
}
```

Replace `actor_id` with the maintainer's team or the `maintain` repository role as the admins
prefer; the request is for the admins, since write access cannot create rulesets.
