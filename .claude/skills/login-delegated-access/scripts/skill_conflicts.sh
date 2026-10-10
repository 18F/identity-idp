#!/usr/bin/env bash
# Lists and classifies open merge or rebase conflicts in the skill and the documents, and shows the
# three-way evidence needed to apply references/conflict-resolution.md. Read-only unless
# --resolve-mechanical is given, which takes the base side for generated and twin paths only.
set -euo pipefail

skill=".claude/skills/login-delegated-access"
resolve=0; [ "${1:-}" = "--resolve-mechanical" ] && resolve=1

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run from the repository root" >&2; exit 2; }
conflicts=$(git diff --name-only --diff-filter=U)
[ -n "$conflicts" ] || { echo "no open conflicts"; exit 0; }

# Direction: in a rebase, HEAD (ours) is the base being rebased onto and the replayed commit is theirs.
if [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]; then
  mode=rebase; base_side=ours; feature_side=theirs
  feature_tip=$(cat "$(git rev-parse --git-path rebase-merge/orig-head)" 2>/dev/null || cat "$(git rev-parse --git-path rebase-apply/orig-head)" 2>/dev/null || echo "")
  base_tip=HEAD
else
  mode=merge; base_side=theirs; feature_side=ours
  feature_tip=HEAD; base_tip=MERGE_HEAD
fi
mb=""; [ -n "$feature_tip" ] && mb=$(git merge-base "$base_tip" "$feature_tip" 2>/dev/null || echo "")
echo "mode: $mode  base side: $base_side  feature side: $feature_side  merge base: ${mb:0:10}"

classify() {
  case "$1" in
    .agents/skills/*) echo twin ;;
    $skill/references/requirements-index.md|$skill/references/traceability.md|$skill/references/branches.md|$skill/references/decisions.md) echo generated ;;
    .claude/skills/*) echo authored ;;
    docs/delegated-access-*.md) echo docs ;;
    *) echo other ;;
  esac
}

while IFS= read -r path; do
  kind=$(classify "$path")
  echo; echo "== $path  [$kind]"
  case "$kind" in
    generated|twin)
      echo "   rule: take the base side, then regenerate (build_index.py) and sync (sync_twins.sh)."
      if [ $resolve = 1 ]; then git checkout --$base_side -- "$path" && git add "$path" && echo "   resolved: base side taken"; fi ;;
    authored|docs)
      if [ -n "$mb" ]; then
        echo "   feature-branch commits touching this path:"
        git log --format='     %h %s' "$mb..$feature_tip" -- "$path" | head -20
        echo "   hunks the feature branch added since the merge base:"
        git diff --stat "$mb" "$feature_tip" -- "$path" | tail -1 | sed 's/^/     /'
        git diff "$mb" "$feature_tip" -- "$path" | grep -E '^[+-][^+-]' | head -40 | sed 's/^/     /'
        echo "   hunks the base added since the merge base:"
        git diff --stat "$mb" "$base_tip" -- "$path" | tail -1 | sed 's/^/     /'
        git diff "$mb" "$base_tip" -- "$path" | grep -E '^[+-][^+-]' | head -40 | sed 's/^/     /'
      fi
      echo "   rule: start from the base version; re-apply only the feature branch's hunks about its own code or decisions (conflict-resolution.md step 4)." ;;
    other) echo "   not a skill or document path; resolve as usual." ;;
  esac
done <<< "$conflicts"
echo; echo "when done: build_index.py, sync_twins.sh, check.sh, then git add and continue."
