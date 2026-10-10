#!/usr/bin/env bash
# Keep .agents/skills a byte-identical copy of .claude/skills.
#
#   scripts/sync_twins.sh          copy .claude/skills over .agents/skills (removing anything extra)
#   scripts/sync_twins.sh --check  compare only; print every differing path and exit 1 on any difference
#
# The source of truth is .claude/skills. scripts/check.sh fails when the twins differ.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source_dir="$root/.claude/skills"
target_dir="$root/.agents/skills"

if [[ ! -d "$source_dir" ]]; then
  echo "sync_twins: missing $source_dir" >&2
  exit 2
fi

if [[ "${1:-}" == "--check" ]]; then
  if [[ ! -d "$target_dir" ]]; then
    echo "twins differ: $target_dir does not exist"
    exit 1
  fi
  # diff -rq lists files that differ and files only present on one side.
  if differences="$(diff -rq "$source_dir" "$target_dir" 2>&1)"; then
    echo "twins identical: .claude/skills == .agents/skills"
    exit 0
  fi
  echo "twins differ (run scripts/sync_twins.sh to copy .claude/skills over .agents/skills):"
  printf '%s\n' "$differences" | sed "s#$root/##g" | sed 's/^/  /'
  exit 1
fi

if [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--check]" >&2
  exit 2
fi

mkdir -p "$(dirname "$target_dir")"
rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$source_dir/." "$target_dir/"
count="$(find "$target_dir" -type f | wc -l | tr -d ' ')"
echo "synced $count files: .claude/skills -> .agents/skills"
