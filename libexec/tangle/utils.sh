#!/usr/bin/env bash
set -euo pipefail

tangle::config_get() { git config --get "$1" || true; }

tangle::bool() {
  case "${1:-}" in 1|true|yes|on|enable|enabled) echo "true" ;; *) echo "false" ;; esac
}

tangle::default_branch() {
  local cfg; cfg="$(tangle::config_get tangle.defaultBranch)"
  if [[ -n "$cfg" ]]; then echo "$cfg"; return; fi
  local ref; ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$ref" ]]; then echo "${ref#origin/}"; return; fi
  for c in main master trunk; do
    if git show-ref --verify --quiet "refs/heads/$c"; then echo "$c"; return; fi
  done
  git rev-parse --abbrev-ref HEAD
}

tangle::prefix() { local v; v="$(tangle::config_get "$1")"; [[ -n "$v" ]] && echo "$v" || echo "$2"; }
tangle::merge_style() { local v; v="$(tangle::config_get tangle.mergeStyle)"; [[ -z "$v" ]] && v="no-ff"; echo "$v"; }
tangle::auto_push() { local v; v="$(tangle::config_get tangle.autoPush)"; [[ -z "$v" ]] && v="true"; tangle::bool "$v"; }
tangle::rebase_on_finish() { local v; v="$(tangle::config_get tangle.rebaseOnFinish)"; [[ -z "$v" ]] && v="false"; tangle::bool "$v"; }
tangle::tag_prefix() { tangle::config_get tangle.tagPrefix; }

tangle::ensure_clean_worktree() {
  if ! git diff-index --quiet HEAD --; then
    echo "[tangle] ERROR: Worktree is dirty. Commit or stash your changes." >&2
    exit 1
  fi
}
tangle::ensure_branch_exists() { git show-ref --verify --quiet "refs/heads/$1" || { echo "[tangle] ERROR: Branch '$1' not found." >&2; exit 1; }; }
tangle::remote_available() { git remote -v | grep -qE 'origin\s' && echo true || echo false; }
tangle::fetch_origin_if_possible() { [[ "$(tangle::remote_available)" == "true" ]] && git fetch -q origin || true; }
tangle::create_branch_from() { git checkout -q -b "$1" "$2"; }

tangle::finish_merge() {
  local def="$1" topic="$2"
  git checkout -q "$def"
  if [[ "$(tangle::rebase_on_finish)" == "true" ]]; then
    git checkout -q "$topic"
    git rebase "$def" || true
    git checkout -q "$def"
  fi
  local style; style="$(tangle::merge_style)"
  if [[ "$style" == "no-ff" ]]; then
    git merge --no-ff -m "Merge $topic into $def" "$topic"
  else
    git merge --ff "$topic" || git merge "$topic"
  fi
  git branch -d "$topic" >/dev/null 2>&1 || git branch -D "$topic"
}

tangle::maybe_push() {
  if [[ "$(tangle::auto_push)" == "true" ]]; then
    if [[ "$(tangle::remote_available)" == "true" ]]; then
      git push -u origin "$(git rev-parse --abbrev-ref HEAD)" || echo "[tangle] WARNING: push failed."
      local topic="$1"
      if git ls-remote --heads origin "$topic" >/dev/null 2>&1; then
        git push origin --delete "$topic" >/dev/null 2>&1 || true
      fi
    else
      echo "[tangle] NOTE: no 'origin' remote; skipped push."
    fi
  fi
}

tangle::tag_release() {
  local version="$1"; local prefix; prefix="$(tangle::tag_prefix)"
  local tag; if [[ -n "$prefix" ]]; then tag="${prefix}${version}"; else tag="${version}"; fi
  git tag -a "$tag" -m "Release $tag"
  if [[ "$(tangle::auto_push)" == "true" ]] && [[ "$(tangle::remote_available)" == "true" ]]; then
    git push origin "$tag" || echo "[tangle] WARNING: tag push failed."
  fi
}