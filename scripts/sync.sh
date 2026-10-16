#!/bin/bash
# Move the local patch set onto the newest upstream release tag.
#   - finds the newest upstream tag vX.Y.Z and the newest local/<ver>-fc<N> branch on the fork
#   - if upstream is newer: new branch local/<newver>-fc1 = new tag + the old patch commits
#     (commits already contained upstream become empty and are dropped; "ci:" commits are skipped)
#   - pushes ONLY that branch (never tags) and dispatches build-image
# Exit codes: 0 ok / nothing to do, 2 conflict, 3 patch set is empty (upstream has everything:
# switch back to the stock image), 4 push rejected.
# Env: UPSTREAM_REMOTE (default upstream) FORK_REMOTE (default origin) DRY_RUN=1 (no push/dispatch)
set -euo pipefail
UP=${UPSTREAM_REMOTE:-upstream}; FORK=${FORK_REMOTE:-origin}
say(){ echo "[sync] $*"; [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$*" >> "$GITHUB_STEP_SUMMARY" || true; }

git fetch -q --no-tags "$UP" '+refs/heads/master:refs/remotes/'"$UP"'/master'
latest_tag=$(git ls-remote --tags --refs "$UP" 'v*' | sed 's|.*refs/tags/||' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
[ -n "$latest_tag" ] || { say "no upstream release tag found"; exit 1; }

git fetch -q --prune "$FORK" '+refs/heads/local/*:refs/remotes/'"$FORK"'/local/*'
cur_branch=$(git branch -r --list "$FORK/local/*-fc*" | sed "s|^ *$FORK/||" | sort -V | tail -1)
[ -n "$cur_branch" ] || { say "no local/<ver>-fc<N> branch on $FORK"; exit 1; }
cur_ver=$(echo "$cur_branch" | sed -E 's|local/(.*)-fc[0-9]+|\1|'); cur_tag="v$cur_ver"

say "upstream latest: $latest_tag | current patch branch: $cur_branch (base $cur_tag)"
if [ "$(printf '%s\n%s\n' "$cur_tag" "$latest_tag" | sort -V | tail -1)" = "$cur_tag" ]; then say "up to date, nothing to do"; exit 0; fi

new_branch="local/${latest_tag#v}-fc1"
if git ls-remote --exit-code --heads "$FORK" "$new_branch" >/dev/null 2>&1; then say "$new_branch already exists on $FORK"; exit 0; fi

git fetch -q --no-tags "$UP" "refs/tags/$cur_tag:refs/tags/$cur_tag" "refs/tags/$latest_tag:refs/tags/$latest_tag"
git checkout -q -B "$new_branch" "$latest_tag"
applied=0
for c in $(git rev-list --reverse "$cur_tag..refs/remotes/$FORK/$cur_branch"); do
  s=$(git log -1 --format=%s "$c")
  case "$s" in ci:*) say "skip   $s"; continue;; esac
  if git cherry-pick -x "$c" >/dev/null 2>&1; then say "applied $s"; applied=$((applied+1))
  elif [ -z "$(git diff --name-only --diff-filter=U)" ] && git diff --cached --quiet; then git cherry-pick --skip >/dev/null 2>&1 || git cherry-pick --abort 2>/dev/null || true; say "DROPPED (already upstream) $s"
  else say "CONFLICT on: $s"; git diff --name-only --diff-filter=U | sed 's/^/  - /' | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"; git cherry-pick --abort 2>/dev/null || true; exit 2; fi
done
if [ "$(git rev-list --count "$latest_tag..HEAD")" -eq 0 ]; then say "patch set is EMPTY: $latest_tag already contains every fix. Use the stock image decolua/9router:${latest_tag#v}"; exit 3; fi

if [ "${DRY_RUN:-}" = 1 ]; then say "DRY RUN: would push $new_branch ($(git rev-list --count "$latest_tag..HEAD") commits) and dispatch build-image"; exit 0; fi
git push "$FORK" "refs/heads/$new_branch:refs/heads/$new_branch" || { say "push rejected (upstream may have changed workflow files; run upgrade.sh locally and push)"; exit 4; }
if [ -n "${GH_TOKEN:-}" ] && command -v gh >/dev/null; then gh workflow run build-image.yml --ref ci -f branch="$new_branch" && say "dispatched build-image for $new_branch"; fi
